module RedClothParslet::Formatter
  class HTML
    attr_accessor :options

    def initialize(options={})
      @options = {:link_aliases => {}}.merge(options)
    end

    def convert(root)
      @output = ""
      @stack = []
      send(root.type, root)
    end

    ESCAPE_MAP = {
      '<' => '&lt;',
      '>' => '&gt;',
      '&' => '&amp;',
      '"' => '&quot;',
      "\n" => "<br />\n",
      "'" => "&#39;",
      "--" => "&#8212;",
      " -" => " &#8211;",
      "x" => "&#215;",
      "..." => "&#8230;",
      "(TM)"=>"&#8482;",
      "(tm)"=>"&#8482;",
      "(C)"=>"&#169;",
      "(c)"=>"&#169;",
      "(R)"=>"&#174;",
      "(r)"=>"&#174;"
    }
    TYPOGRAPHIC_ESCAPE_MAP = ESCAPE_MAP.merge("'" => "&#8217;")
    CHARS_TO_BE_ESCAPED = {
      :all => /<|>|&|\n|"|'/,
      :pre => /<|>|&|'|"/,
      :attribute => /<|>|&|"/
    }

    def textile_doc(el)
      inner(el, true).strip
    end

    ([:h1, :h2, :h3, :h4, :h5, :h6, :div] +
     [:strong, :em, :i, :b, :ins, :del, :sup, :sub, :span, :cite, :acronym]).each do |m|
      define_method(m) do |el|
        "<#{m}#{html_attributes(el.opts)}>#{inner(el)}</#{m}>"
      end
     end

    def p(el)
      inner = inner(el)
      # Curlify multi-paragraph quote (one that doesn't have a closing quotation mark)
      if el.opts.delete(:possible_unfinished_quote_paragraph)
        inner.sub!(/\A#{ESCAPE_MAP['"']}/, "&#8220;")
      end
      "<p#{html_attributes(el.opts)}>#{inner}</p>"
    end

    [:blockquote, :dl].each do |m|
      define_method(m) do |el|
        "<#{m}#{html_attributes(el.opts)}>\n#{inner(el, true)}</#{m}>"
      end
    end

    [:ul, :ol].each do |m|
      define_method(m) do |el|
        @list_nesting ||= 0
        out = ""
        out << "\n" if @list_nesting > 0
        out << "\t" * @list_nesting
        @list_nesting += 1
        out << "<#{m}#{html_attributes(el.opts)}>\n"
        out << list_items(el)
        out << "</li>\n"
        out << "\t" * (@list_nesting - 1)
        @list_nesting -= 1
        out << "</#{m}>"
        out
      end
    end

    def li(el)
      ("\t" * @list_nesting) +
        "<li#{html_attributes(el.opts)}>#{inner(el)}"
    end

    [:dt, :dd].each do |m|
      define_method(m) do |el|
        "\t<#{m}>#{inner(el)}</#{m}>"
      end
    end

    def link(el)
      href = el.opts[:href]
      if link_alias = options[:link_aliases][href]
        href.replace link_alias
      end
      "<a#{html_attributes(el.opts)}>#{inner(el)}</a>"
    end

    def img(el)
      if el.opts[:alt] && el.opts[:alt] != ''
        el.opts[:title] = el.opts[:alt]
      else
        el.opts[:alt] = ""
      end
      %Q{<img#{html_attributes(el.opts, :image)} />}
    end

    def table(el)
      "<table#{html_attributes(el.opts)}>\n#{inner(el)}</table>"
    end
    def table_row(el)
      "\t<tr#{html_attributes(el.opts)}>\n#{inner(el)}\t</tr>\n"
    end
    def table_data(el)
      "\t\t<td#{html_attributes(el.opts)}>#{inner(el)}</td>\n"
    end
    def table_header(el)
      "\t\t<th#{html_attributes(el.opts)}>#{inner(el)}</th>\n"
    end

    def double_quoted_phrase(el)
      "&#8220;#{inner(el)}&#8221;"
    end

    def dimension(el)
      el.to_s.gsub(/['"]/) {|m| {"\"" => '&#8243;', "'" => '&#8242;'}[m] }
    end

    def caps(el)
      el.opts.merge!({:class => 'caps'})
      span(el)
    end

    def footnote_reference(el)
      %Q{<sup class="footnote" id="fnr#{el.to_s}"><a href="#fn#{el.to_s}">1</a></sup>}
    end

    def footnote(el)
      num = el.opts.delete(:number)
      el.opts[:class] = [el.opts[:class], 'footnote'].compact.join(" ")
      el.opts[:id] = "fn" + num
      %Q{<p#{html_attributes(el.opts)}><a href="#fnr#{num}"><sup>#{num}</sup></a> #{inner(el)}</p>}
    end

    def hr(el)
      "<hr />"
    end

    %w(pre code).each do |tag|
      define_method(tag) do |el|
        (el.opts.delete(:open_tag) || "<#{tag}#{html_attributes(el.opts)}>") +
          inner(el, nil, :pre) + "</#{tag}>"
      end
    end

    def blockcode(el)
      "<pre#{html_attributes(el.opts)}><code>#{escape_html(el.to_s, :pre)}</code></pre>"
    end

    def notextile(el)
      el.children.join
    end

    def html_tag(el)
      el.children.join
    end

    def entity(el)
      ESCAPE_MAP[el.to_s] || el.to_s
    end

    private

    def list_items(el, block=false)
      result = ''
      @stack.push(el)
      el.children.each_with_index do |inner_el, index|
        result << "</li>\n" if inner_el.is_a?(RedClothParslet::Ast::Li) && index > 0
        result << send(inner_el.type, inner_el)
        result << "\n" if block
      end
      @stack.pop
      result
    end

    # Return the converted content of the children of +el+ as a string.
    # Pushes +el+ onto the @stack before converting the child elements and pops it from the stack
    # afterwards.
    def inner(el, block = false, escape_type = nil)
      result = ''
      @stack.push(el)
      el.children.flatten.each do |inner_el|
        if inner_el.is_a?(String)
          result << escape_html(inner_el, escape_type)
        elsif inner_el.respond_to?(:type)
          result << send(inner_el.type, inner_el)
        end
        result << "\n" if block
      end
      @stack.pop
      result
    end


    # Return the HTML representation of the attributes +attr+.
    def html_attributes(attr, type=:text)
      if attr[:style]
        attr[:style] = attr[:style].map do |k,v|
          case k
          when /padding/
            "#{k}:#{v}em"
          when 'align'
            align_attribute(v, type)
          else
            [k,v].join(':')
          end
        end
        attr[:style].sort! if options[:sort_attributes]
        attr[:style] = attr[:style].join(";") + ";"
      end
      sort_attributes(attr).map {|k,v| v.nil? ? '' : " #{k}=\"#{escape_html(v.to_s, :attribute)}\"" }.join('')
    end

    def align_attribute(v, type)
      case type
      when :text
        "text-align:#{v}"
      when :image
        "float:#{v}"
      else
        "align:#{v}"
      end
    end

    def sort_attributes(attributes)
      return attributes unless options[:sort_attributes]
      # Stringify keys, then sort
      attributes.inject({}) do |attrs, (key, value)|
        attrs[key.to_s] = value
        attrs
      end.sort
    end

    def escape_html(str, type = :all)
      type = :all unless CHARS_TO_BE_ESCAPED.keys.include? type
      escape_map = type == :pre ? ESCAPE_MAP : TYPOGRAPHIC_ESCAPE_MAP
      str.gsub(CHARS_TO_BE_ESCAPED[type]) {|m| escape_map[m] || m }
    end

  end
end
