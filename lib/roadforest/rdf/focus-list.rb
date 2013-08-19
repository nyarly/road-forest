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
  end
end
