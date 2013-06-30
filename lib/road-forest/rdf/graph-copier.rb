require 'rdf'
require 'road-forest/rdf/graph-focus'

module RoadForest
  module RDF
    class GraphCopier < GraphFocus
      attr_accessor :source_graph, :subject

      alias target_graph graph_manager

      def initialize
        @graph_manager = ::RDF::Graph.new
      end
    end
  end
end
