require 'road-forest/rdf'
require 'road-forest/rdf/credence'
require 'road-forest/rdf/investigator'
require 'rdf'

module RoadForest::RDF
  class NotCredible < StandardError; end
  class QueryHandler
    include Normalization

    class << self
      def cached
        @cached ||=
          begin
            cached = {}
            cached[:simple] = QueryHandler.new do |handler|
              handler.policy_list(:must_local, :may_local)
              handler.investigators = [NullInvestigator.new]
            end
            cached[:http] = QueryHandler.new do |handler|
              handler.policy_list(:may_subject, :any) #XXX
              handler.investigators = [HTTPInvestigator.new, NullInvestigator.new]
            end
            cached
          end
      end

      def [](name)
        cached[name]
      end

      def []=(name, value)
        cached[name] = value
      end
    end

    class ContextNotes
      attr_reader :graph_manager, :context_roles

      def initialize(graph_manager, context_roles, raw_contexts)
        @graph_manager = graph_manager
        @context_roles = context_roles
        @raw_contexts = raw_contexts
      end

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
    end

    class CommonResults < ContextNotes
      attr_reader :items, :query_pattern

      def initialize(graph_manager, context_roles, query_pattern)
        @query_pattern = query_pattern
        @graph_manager = graph_manager
        @items = query
        super(graph_manager, context_roles, items.map(&:context))
      end

      def http_client
        graph_manager.http_client
      end

      def by_context
        @by_context ||= Hash[contexts.map do |context|
          [context, @items.filter do |item|
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

      def requery
        self.class.new(graph_manager, context_roles, query_pattern)
      end
    end

    class StatementResults < CommonResults
      alias statements items

      def query
        graph_manager.find_statements(query_pattern)
      end

      def empty_result
        []
      end
    end

    class QueryResults < CommonResults
      alias solutions items

      def query
        puts; puts "#{__FILE__}:#{__LINE__} => \n#{(query_pattern).inspect}"
        puts; puts "#{__FILE__}:#{__LINE__} => \n#{(graph_manager.graph_dump(:ntriples))}\n\n"

        graph_manager.query(query_pattern)
      end

      def empty_result
        RDF::Query::Solutions.new
      end
    end

    attr_accessor :investigators, :investigation_limit, :credence_policies
    def initialize
      @investigators = []
      @investigation_limit = 3
      @credence_policies = []
      yield self if block_given?
    end

    def policy_list(*names)
      self.credence_policies = names.map do |name|
        Credence.policy(name)
      end
    end

    def context_roles(graph_manager, subject_uri)
      {
        :local => graph_manager.local_context_node,
        :subject => subject_uri
      }
    end

    def query(graph_manager, subject, pattern)
      query = RDF::Query.new do |query|
        query.pattern(pattern)
      end

      results = QueryResults.new(graph_manager, context_roles(graph_manager, subject), query)
      results = check(results)
    end

    def find_statements(graph_manager, subject, pattern)
      results = StatementResults.new(graph_manager, context_roles(graph_manager, subject), pattern)
      results = check(results)
    end

    def check(results)
      investigators.each do |investigator|
        puts; puts "#{__FILE__}:#{__LINE__} => #{(results.items).inspect}"
        catch :not_credible do
          contexts = results.contexts
          credence_policies.each do |policy|
            contexts = policy.credible(contexts, results)
            if contexts.empty?
              throw :not_credible
            end
          end
          return results.for_context(contexts.first)
        end
        results = investigator.pursue(results)
      end
      raise NoCredibleResults
    end
  end
end
