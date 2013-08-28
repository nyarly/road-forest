require 'rdf/query/pattern'
require 'roadforest/rdf'
require 'roadforest/rdf/graph-store'
require 'roadforest/rdf/investigation'

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

      unless options.nil?
        pattern.context_roles = options[:context_roles]
        pattern.source_rigor = options[:source_rigor]
      end

      yield pattern if block_given?

      pattern
    end

    attr_accessor :context_roles, :source_rigor

    def execute(queryable, bindings = nil, query_context_roles = nil, &block)
      unless queryable.is_a? RoadForest::RDF::GraphStore
        return super(queryable, bindings || {}, &block)
      end

      investigation = Investigation.new
      investigation.queryable = queryable
      investigation.context_roles = (query_context_roles || {}).merge(context_roles)
      investigation.source_rigor = source_rigor

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
  end
end
