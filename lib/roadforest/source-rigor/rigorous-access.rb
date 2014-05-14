require 'roadforest/graph/access-manager'
require 'roadforest/source-rigor/resource-query'
require 'roadforest/source-rigor/resource-pattern'
require 'roadforest/source-rigor/parcel'

module RoadForest
  module SourceRigor
    module Rigorous
      attr_accessor :rigor

      def dup
        other = self.class.allocate
        other.resource = self.resource
        other.rigor = self.rigor
        other.source_graph = self.source_graph

        return other
      end

      def build_query
        ResourceQuery.new([], {}) do |query|
          query.subject_context = resource
          query.source_rigor = rigor
          yield query
        end
      end

      def query_execute(query, &block)
        query = ResourceQuery.from(query, resource, rigor)
        execute_search(query, &block)
      end

      def query_pattern(pattern, &block)
        pattern = ResourcePattern.from(pattern, {:context_roles => {:subject => resource}, :source_rigor => rigor})
        execute_search(pattern, &block)
      end
    end

    class RetrieveManager < Graph::ReadOnlyManager
      include Rigorous
    end

    class PostManager < Graph::WriteManager
      include Rigorous
    end

    class UpdateManager < Graph::SplitManager
      include Rigorous

      def initialize
        @copied_contexts = {}
      end

      attr_accessor :copied_contexts

      def dup
        other = super
        other.copied_contexts = self.copied_contexts
        other.target_graph = self.target_graph
        return other
      end

      def execute_search(search, &block)
        enum = search.execute(destination_graph)
        if enum.any?{ true }
          enum.each(&block)
          return enum
        end
        search.execute(origin_graph, &block)
      end

      def insert(statement)
        copy_context
        statement[3] = resource
        super
      end

      def delete(statement)
        copy_context
        statement = RDF::Query::Pattern.from(statement)
        statement.context = resource
        super(statement)
      end

      def parceller
        @parceller ||=
          begin
            parceller = Parcel.new
            parceller.graph = source_graph
            parceller
          end
      end

      def copy_context
        return if copied_contexts[resource]
        parceller.graph_for(resource).each_statement do |statement|
          statement.context = resource
          destination_graph << statement
        end
        copied_contexts[resource] = true
      end
    end
  end
end
