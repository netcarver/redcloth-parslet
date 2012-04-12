require File.dirname(__FILE__) + '/../spec_helper'

describe "html_no_breaks" do
  examples_from_yaml do |doc|
    red = RedClothParslet.new(doc['in'])
    red.hard_breaks = false
    red.to_html(:sort_attributes)
  end
end
