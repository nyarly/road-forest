require 'rdf'
require 'roadforest/rdf/resource-query'
require 'roadforest/rdf/resource-pattern'
require 'roadforest/rdf/normalization'
require 'roadforest/rdf/parcel'

module RoadForest::RDF
  class ContextFascade
    include ::RDF::Countable
    include ::RDF::Enumerable
    include ::RDF::Queryable
    include Normalization

    attr_accessor :resource, :rigor, :source_graph, :target_graph, :copied_contexts

    def initialize
      @copied_contexts = {}
    end

    def resource=(resource)
      @resource = normalize_context(resource)
    end

    def dup
      other = self.class.allocate
      other.resource = self.resource
      other.rigor = self.rigor

      other.copied_contexts = self.copied_contexts
      other.source_graph = self.source_graph
      other.target_graph = self.target_graph
      return other
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
      return if target_graph.nil? or source_graph == target_graph
      parceller.graph_for(resource).each_statement do |statement|
        statement.context = resource
        target_graph << statement
      end
      copied_contexts[resource] = true
    end

    #superfluous?
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

    def execute_search(search, &block)
      if target_graph != source_graph and not target_graph.nil?
        enum = search.execute(target_graph)
        if enum.any?{ true }
          enum.each(&block)
          return enum
        end
      end
      search.execute(source_graph, &block)
    end

    def each(&block)
      source_graph.each(&block)
    end

    def insert(statement)
      copy_context
      statement[3] = resource
      target_graph.insert(statement)
    end

    def delete(statement)
      statement = RDF::Query::Pattern.from(statement)
      statement.context = resource
      copy_context
      target_graph.delete(statement)
    end
  end
end
