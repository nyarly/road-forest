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
        @cached ||= {
          :simple => QueryHandler.new.tap do |handler|
          handler.policy_list(:must_local, :may_local)
          handler.investigator = NullInvestigator.new
          end
        }
      end

      def [](name)
        cached[name]
      end

      def []=(name, value)
        cached[name] = value
      end
    end

    class QueryResults
      attr_reader :graph_manager, :context_roles, :solutions

      def initialize(graph_manager, context_roles, solutions)
        @graph_manager = graph_manager
        @context_roles = context_roles
        @solutions = solutions
      end

      def by_context
        @by_context ||= Hash[contexts.map do |context|
          [context, @solutions.filter do |solution|
            solution.context == context
          end]
        end]
      end

      def contexts
        @contexts ||= @solutions.map do |solution|
          solution.context
        end.uniq + @context_roles.values.find_all do |context|
          not context_metadata(context).empty?
        end
      end

      def for_context(context)
        by_context[context] || empty_for_context(context)
      end

      def empty_for_context(context)
        if context_metadata(context).empty? #We've never checked
          nil
        else
          RDF::Query::Solutions.new
        end
      end

      def context_metadata(context)
        graph_manager.query_unnamed([context, :property, :value]).select(:property, :value)
      end
    end

    attr_accessor :investigator, :investigation_limit, :credence_policies
    def initialize
      @investigator = nil
      @investigation_limit = 3
      @credence_policies = []
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
      results = QueryResults.new(graph_manager, context_roles(graph_manager, subject), graph_manager.query(pattern))
      results = check(results)
    rescue NotCredible
      results = investigate(graph_manager, results)
    end

    def check(results)
      contexts = results.contexts
      credence_policies.each do |policy|
        contexts = policy.credible(contexts, results)
        raise NotCredible if contexts.empty?
      end
      return results.for_context(contexts.first)
    end

    def investigate(graph_manager, results)
      investigator.pursue(results, graph_manager)
    end
  end
end
