module RedClothParslet
  module Spec
    module Matchers
      
      # Comes from parslet/rig/rspec. Modifications:
      #   * Always trace on parse failure
      #   * Introduce #as_compacted to remove unimportant data
      RSpec::Matchers.define(:parse) do |input, opts|
        match do |parser|
          begin
            @result = parser.parse(input)
            if @block
              @block.call(@result)
            else
              compact_result! if @as_compacted
              (@as == @result || @as.nil?)
            end
          rescue Parslet::ParseFailed
            @trace = parser.error_tree.ascii_tree if true #opts && opts[:trace]
            false
          end
        end
        
        failure_message_for_should do |is|
          if @block
            "expected output of parsing #{input.inspect}" <<
            " with #{is.inspect} to meet block conditions, but it didn't"
          else
            "expected " << 
              (@as ? 
                "output of parsing #{input.inspect}"<<
                " with #{is.inspect} to equal #{@as.inspect}, but was #{@result.inspect}" : 
                "#{is.inspect} to be able to parse #{input.inspect}") << 
              (@trace ? 
                "\n"+@trace : 
                '')
          end
        end

        failure_message_for_should_not do |is|
          if @block
            "expected output of parsing #{input.inspect} with #{is.inspect} not to meet block conditions, but it did"
          else
            "expected " << 
              (@as ? 
                "output of parsing #{input.inspect}"<<
                " with #{is.inspect} not to equal #{@as.inspect}" :

                "#{is.inspect} to not parse #{input.inspect}, but it did")
          end
        end

        # NOTE: This has a nodoc tag since the rdoc parser puts this into 
        # Object, a thing I would never allow. 
        def as(expected_output = nil, &block) # :nodoc: 
          @as = expected_output
          @block = block
          self
        end
        
        def matching(expected_output = nil, &block) # :nodoc: 
          @as_compacted = expected_output
          @block = block
          self
        end
        def compact_result!
          transform = Parslet::Transform.new do
            rule(:pre => [], :c => subtree(:c), :inline => simple(:inline)) { {:c => c, :inline => inline} }
            rule(:pre => [], :s => simple(:s)) { {:s => s} }
          end
          @as = @as_compacted
          @result = transform.apply(@result)
        end
        
      end
      
      
    end
  end
end
