require 'road-forest/rdf'
require 'rdf/query'

module RoadForest::RDF
  class ResourceQuery < ::RDF::Query
    def initialize(patterns = [], options = {}, &block)
      @subject_context = options[:subject_context]
      super
      patterns = @patterns
      @patterns.clear
      patterns.each do |pattern|
        pattern(pattern)
      end
    end

    attr_accessor :subject_context, :source_skepticism
    attr_accessor :patterns, :variables, :solutions, :options

    def <<(pattern)
      pattern(pattern)
    end

    def pattern(pattern, options = nil)
      options = {
        :context_roles => {:subject => subject_context},
        :source_skepticism => source_skepticism
      }.merge(options || {})

      @patterns << ResourcePattern.from(pattern, options)
      self
    end

    def self.from(other, subject_context = nil)
      query = self.new
      query.subject_context = subject_context
      query.source_skepticism = source_skepticism
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
