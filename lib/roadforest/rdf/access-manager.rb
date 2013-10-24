require 'rdf'
require 'roadforest/rdf/resource-query'
require 'roadforest/rdf/resource-pattern'
require 'roadforest/rdf/normalization'
require 'roadforest/rdf/parcel'

module RoadForest::RDF
  class ReadOnlyManager
    include ::RDF::Countable
    include ::RDF::Enumerable
    include ::RDF::Queryable
    include Normalization

    attr_accessor :resource, :rigor, :source_graph

    def resource=(resource)
      @resource = normalize_context(resource)
    end

    def dup
      other = self.class.allocate
      other.resource = self.resource
      other.rigor = self.rigor
      other.source_graph = self.source_graph

      return other
    end

    alias origin_graph source_graph
    alias destination_graph source_graph

    def build_query
      ResourceQuery.new([], {}) do |query|
        query.subject_context = resource
        query.source_rigor = rigor
        yield query
      end
    end

    def relevant_prefixes
      relevant_prefixes_for_graph(origin_graph)
    end

    def query_execute(query, &block)
      query = ResourceQuery.from(query, resource, rigor)
      execute_search(query, &block)
    end

    def query_pattern(pattern, &block)
      pattern = ResourcePattern.from(pattern, {:context_roles => {:subject => resource}, :source_rigor => rigor})
      execute_search(pattern, &block)
    end

    def each(&block)
      origin_graph.each(&block)
    end

    def execute_search(search, &block)
      search.execute(origin_graph, &block)
    end
  end

  class WriteManager < ReadOnlyManager
    def insert(statement)
      statement[3] = resource
      destination_graph.insert(statement)
    end

    def delete(statement)
      statement = RDF::Query::Pattern.from(statement)
      statement.context = resource
      destination_graph.delete(statement)
    end
  end

  class PostManager < WriteManager
  end

  class SplitManager < WriteManager
    attr_accessor :target_graph

    alias destination_graph target_graph

    def dup
      other = super
      other.target_graph = self.target_graph
      return other
    end

    def relevant_prefixes
      super.merge(relevant_prefixes_for_graph(destination_graph))
    end
  end

  class UpdateManager < SplitManager
    def initialize
      @copied_contexts = {}
    end

    attr_accessor :copied_contexts

    def dup
      other = super
      other.copied_contexts = self.copied_contexts
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
      super
    end

    def delete(statement)
      copy_context
      super
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

  class CopyManager < SplitManager
  end
end
