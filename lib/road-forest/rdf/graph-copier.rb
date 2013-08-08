require 'rdf'
require 'road-forest/rdf/graph-focus'

module RoadForest
  module RDF
    class GraphCopier < GraphFocus
      attr_accessor :source_graph, :subject

      alias target_graph graph_store

      def initialize
        @graph_store = ::RDF::Graph.new
      end
    end
  end
end
