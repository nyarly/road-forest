require 'road-forest/rdf'
require 'rdf/query/pattern'

module RoadForest::RDF
  class ResourcePattern < ::RDF::Query::Pattern
    class Investigation
      attr_accessor :context_roles, :graph_manager, :results

      def http_client
        graph_manager.http_client
      end


      def found_results?
        !@results.nil?
      end
    end

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

    def investigators
      source_skepticism.investigators
    end

    def credence_policies
      source_skepticism.credence_policies
    end

    def execute(queryable, bindings = nil, query_context_roles = nil, &block)
      investigation = Investigation.new
      investigation.graph_manager = queryable
      investigation.context_roles = (query_context_roles || {}).merge(context_roles)

      investigators.each do |investigator|
        results = []
        super(queryable, bindings || {}) do |statement|
          results << statement
        end
        contexts = result_contexts(results)

        catch :not_credible do
          credence_policies.each do |policy|
            contexts = policy.credible(contexts, results)
            if contexts.empty?
              throw :not_credible
            end
          end
          return results_for_context(results, contexts.first)
        end
        investigator.pursue(investigation)

        if investigation.found_results?
          return investigation.results
        end
      end
      raise NoCredibleResults
    end

    def context
      @context ||= ::RDF::Query::Variable.new(:context)
    end

    def result_contexts(queryable, results)
      (results.map(&:context) +
        context_roles.values.find_all do |context|
        not context_metadata(queryable, context).empty?
        end).uniq
    end

    def context_metadata(queryable, context)
      query = RDF::Query.new do |query|
        query.pattern [context, :property, :value]
      end
      query.execute(queryable.unnamed_graph).select(:property, :value)
    end

    def results_for_context(results, context)
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
