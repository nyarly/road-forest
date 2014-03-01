require 'roadforest/rdf'
require 'rdf/query'

module RoadForest::RDF
  class ResourceQuery < ::RDF::Query
    def initialize(patterns = [], options = {}, &block)
      @subject_context = options[:subject_context]
      @source_rigor = options[:source_rigor]
      super
      patterns = @patterns.dup
      @patterns.clear
      patterns.each do |pattern|
        pattern(pattern)
      end
    end

    attr_accessor :subject_context, :source_rigor
    attr_accessor :patterns, :variables, :solutions, :options

    def <<(pattern)
      pattern(pattern)
    end

    def pattern(pattern, options = nil)
      options = {
        :context_roles => {:subject => subject_context},
        :source_rigor => source_rigor
      }.merge(options || {})

      @patterns << ResourcePattern.from(pattern, options)
      self
    end

    def self.from(other, subject_context = nil, source_rigor = nil)
      query = self.new

      if subject_context.nil? and other.respond_to?(:subject_context)
        query.subject_context = other.subject_context
      else
        query.subject_context = subject_context
      end

      if source_rigor.nil? and other.respond_to?(:source_rigor)
        query.source_rigor = other.source_rigor
      else
        query.source_rigor = source_rigor
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
