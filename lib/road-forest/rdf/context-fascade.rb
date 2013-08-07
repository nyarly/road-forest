require 'rdf'

module RoadForest::RDF
  class ContextFascade
    include ::RDF::Countable
    include ::RDF::Enumerable
    include ::RDF::Queryable

    def initialize(manager, resource, rigor)
      @manager, @resource, @rigor = manager, resource, rigor
    end

    def query_execute(query, &block)
      ResourceQuery.from(query, @resource, @rigor).execute(@manager, &block)
    end

    def query_pattern(pattern, &block)
      ResourcePattern.from(pattern, {:context_roles => {:subject => @resource}, :source_rigor => @rigor}).execute(@manager, &block)
    end

    def each(&block)
      @manager.each(&block)
    end
  end
end
