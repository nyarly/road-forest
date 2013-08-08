require 'road-forest/rdf/focus-wrapping'
require 'road-forest/rdf/normalization'
module RoadForest::RDF
  class FocusList < ::RDF::List
    include Normalization
    include FocusWrapping

    attr_accessor :root_url, :base_node, :source_rigor

    def new_focus
      base_node.dup
    end

    def each
      super do |value|
        yield unwrap_value(value)
      end
    end
  end
end
