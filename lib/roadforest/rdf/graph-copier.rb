require 'rdf'
require 'roadforest/rdf/graph-focus'

module RoadForest
  module RDF
    class GraphCopier < GraphReading
      def target_graph
        @access_manager.target_graph
      end

      def target_graph=(graph)
        @access_manager.target_graph = graph
      end

      def query_value(query)
        #This isn't the most efficient way to do this (the query essentially
        #happens twice) but the intended use of GC is to copy small numbers of
        #patterns between small graphs, so the n is small
        query.patterns.each do |pattern|
          pattern.execute(@access_manager) do |statement|
            @access_manager.insert(statement)
          end
        end
        super
      end
    end
  end
end
