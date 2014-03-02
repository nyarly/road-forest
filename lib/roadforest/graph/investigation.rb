require 'roadforest/rdf'

module RoadForest::Graph
  class Investigation
    attr_accessor :context_roles, :queryable, :results, :source_rigor

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
      source_rigor.investigators
    end

    def credence_policies
      source_rigor.credence_policies
    end

    def make_request(method, url, graph=nil)
      source_rigor.graph_transfer.make_request(method, url, graph)
    end

    def insert_graph(context, graph)
      queryable.insert_graph(context, graph)
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
      results.find_all do |item|
        item.context == context
      end
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
