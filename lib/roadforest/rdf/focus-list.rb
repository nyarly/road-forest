require 'roadforest/rdf/focus-wrapping'
require 'roadforest/rdf/normalization'
module RoadForest::RDF
  class FocusList < ::RDF::List
    include Normalization

    attr_accessor :root_url, :base_node, :source_rigor

    def first
      base_node.unwrap_value(super)
    end

    def each
      super do |value|
        yield base_node.unwrap_value(value)
      end
    end

    def append_node(subject=nil)
      base_node.create_node(subject) do |node|
        self << node.subject
        yield node if block_given?
      end
    end
  end
end
