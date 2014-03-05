require 'roadforest/rdf'

module RoadForest::SourceRigor
  class CredenceAnnealer
    def initialize(graph)
      @graph = graph
      @attempts = 5
    end

    attr_accessor :attempts

    def resolve(&block)
      attempts = @attempts

      @graph.force_impulse

      begin
        raise "Annealing failed after #@attempts attempts" if (attempts -= 1) < 0
        @graph.next_impulse
        block.call
      end until @graph.quiet_impulse?
    end
  end
end
