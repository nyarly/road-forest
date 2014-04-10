require 'rdf'
require 'roadforest/graph/vocabulary'

module RoadForest
  class PathMatcher
    class Match
      attr_accessor :graph
    end

    attr_accessor :pattern

    def match(root, graph)
      return Match.new
    end
  end

end
