require 'road-forest/rdf'
require 'rdf/query'

module RoadForest::RDF
  class ContextualQuery < ::RDF::Query
    def initialize(patterns = [], options = {}, &block)
      @subject_context = options[:subject_context]
      super
    end

    attr_accessor :subject_context

    def self.from(other, subject_context = nil)
      query = self.new
      query.subject_context = subject_context
      query.patterns = other.patterns
      query.variables = other.variables
      query.solutions = other.solutions
      query.options = other.options
    end
  end
end
