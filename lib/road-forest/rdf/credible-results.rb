require 'road-forest/rdf'
require 'road-forest/rdf/credence'
require 'road-forest/rdf/investigator'
require 'rdf'

module RoadForest::RDF
  class NotCredible < StandardError; end

  class QueryResults
    attr_reader :graph_manager, :context_roles
    attr_reader :items, :query_pattern

    def contexts
      @contexts ||= (@raw_contexts +
                     @context_roles.values.find_all do |context|
        not context_metadata(context).empty?
                     end).uniq
    end

    def context_metadata(context)
      query = RDF::Query.new do |query|
        query.pattern [context, :property, :value]
      end
      graph_manager.query_unnamed(query).select(:property, :value)
    end

    def initialize(graph_manager, context_roles, query_pattern)
      @query_pattern = query_pattern
      @graph_manager = graph_manager
      @context_roles = context_roles
      @items = query
      @raw_contexts = items.map(&:context)
    end

    alias statements items
    alias solutions items

    def http_client
      graph_manager.http_client
    end

    def by_context
      @by_context ||= Hash[contexts.map do |context|
        [context, @items.find_all do |item|
          item.context == context
        end]
      end]
    end

    def for_context(context)
      by_context[context] || empty_for_context(context)
    end

    def empty_for_context(context)
      if context_metadata(context).empty? #We've never checked
        nil
      else
        empty_result
      end
    end

    def query
      graph_manager.query(query_pattern)
    end

    def requery
      self.class.new(graph_manager, context_roles, query_pattern)
    end

    def empty_result
      case query_pattern
      when ::RDF::Query
        RDF::Query::Solutions.new
      else
        []
      end
    end
  end
end
