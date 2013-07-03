require 'road-forest/rdf'
require 'rdf/query/pattern'

module RoadForest::RDF
  class ResourcePattern < ::RDF::Query::Pattern
    def self.from(pattern, options)
      pattern = case pattern
        when self
          pattern
        when ::RDF::Query::Pattern
          options ||= {}
          self.new(pattern.subject, pattern.predicate, pattern.object, options.merge(:context => pattern.context))
        when Array, ::RDF::Statement
          options ||= {}
          self.new(pattern[0], pattern[1], pattern[2], options.merge(:context => pattern[3]))
        when Hash
          options ||= {}
          self.new(options.merge(pattern))
        else
          raise ArgumentError, "expected RoadForest::RDF::ResourcePattern, RDF::Query::Pattern, RDF::Statement, Hash, or Array, but got #{pattern.inspect}"
      end

      pattern.context_roles = options[:context_roles] unless options.nil?
      pattern.source_skepticism = options[:source_skepticism] unless options.nil?

      yield pattern if block_given?

      pattern
    end

    attr_accessor :context_roles, :source_skepticism

    def execute(queryable, bindings = nil, query_context_roles = nil, &block)
      investigation = Investigation.new
      investigation.queryable = queryable
      investigation.context_roles = (query_context_roles || {}).merge(context_roles)
      investigation.source_skepticism = source_skepticism

      results = investigation.result do |results|
        super(queryable, bindings || {}) do |statement|
          results << statement
        end
      end

      results.each(&block) if block_given?
      results
    end

    def context
      @context ||= ::RDF::Query::Variable.new(:context)
    end

    class Investigation
      attr_accessor :context_roles, :queryable, :results, :source_skepticism

      def initialize
        @results = []
      end

      def http_client
        queryable.http_client
      end

      def found_results?
        !@results.nil?
      end

      def investigators
        source_skepticism.investigators
      end

      def credence_policies
        source_skepticism.credence_policies
      end

      def result
        investigators.each do |investigator|
          self.results = []
          yield(results)

          contexts = result_contexts

          catch :not_credible do
            credence_policies.each do |policy|
              contexts = policy.credible(contexts, self)
              if contexts.empty?
                throw :not_credible
              end
            end
            return results_for_context(contexts.first)
          end

          self.results = nil
          investigator.pursue(self)

          if found_results?
            return results
          end
        end
        raise NoCredibleResults
      end

      def result_contexts
        (results.map(&:context) +
         context_roles.values.find_all do |context|
          not context_metadata(context).empty?
         end).uniq
      end

      def context_metadata(context)
        query = RDF::Query.new do |query|
          query.pattern [context, :property, :value]
        end
        query.execute(queryable.unnamed_graph).select(:property, :value)
      end

      def results_for_context(context)
        results.find_all{|item| item.context == context}
      end

      #XXX Do we need the nil result if context_metadata is empty?
      def empty_for_context(context)
        if context_metadata(context).empty? #We've never checked
          nil
        else
          empty_result
        end
      end
    end
  end
end
