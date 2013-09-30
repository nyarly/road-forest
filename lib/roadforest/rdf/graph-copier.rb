require 'rdf'
require 'roadforest/rdf/graph-focus'

module RoadForest
  module RDF
    class GraphCopier < GraphWriting
      attr_accessor :target_graph

      def initialize
        super
        @target_graph = ::RDF::Graph.new
      end
    end
  end
end
