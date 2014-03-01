require 'roadforest/rdf/graph-focus'

module RoadForest::RDF
  class PostFocus < GraphFocus

    attr_accessor :graphs

    def dup
      other = super
      other.graphs = graphs
      other
    end

    def post_to
      graph = ::RDF::Graph.new
      access = WriteManager.new
      access.source_graph = graph
      focus = GraphFocus.new(access, subject)

      graphs[subject] = graph

      yield focus if block_given?
      return focus
    end
  end
end
