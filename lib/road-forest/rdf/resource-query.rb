require 'road-forest/rdf'
require 'rdf/query'

module RoadForest::RDF
  class ResourceQuery < ::RDF::Query
    def initialize(patterns = [], options = {}, &block)
      @subject_context = options[:subject_context]
      @source_skepticism = options[:source_skepticism]
      super
      patterns = @patterns.dup
      @patterns.clear
      patterns.each do |pattern|
        pattern(pattern)
      end
    end

    attr_accessor :subject_context, :source_skepticism, :graph_transfer
    attr_accessor :patterns, :variables, :solutions, :options

    def <<(pattern)
      pattern(pattern)
    end

    def pattern(pattern, options = nil)
      options = {
        :context_roles => {:subject => subject_context},
        :graph_transfer => graph_transfer,
        :source_skepticism => source_skepticism
      }.merge(options || {})

      @patterns << ResourcePattern.from(pattern, options)
      self
    end

    def self.from(other, subject_context = nil, source_skepticism = nil)
      query = self.new

      if subject_context.nil? and other.respond_to?(:subject_context)
        query.subject_context = other.subject_context
      else
        query.subject_context = subject_context
      end

      if source_skepticism.nil? and other.respond_to?(:source_skepticism)
        query.source_skepticism = other.source_skepticism
      else
        query.source_skepticism = source_skepticism
      end

      other.patterns.each do |pattern|
        query.pattern(pattern)
      end
      query.variables = other.variables
      query.solutions = other.solutions
      query.options = other.options
      return query
    end
  end
end
