require 'roadforest/rdf/graph-focus'

module RoadForest::RDF
  class PostFocus < GraphFocus
    def initialize(subject = nil, graph = nil , rigor = nil)
      super(subject, graph, rigor)
      @graphs = {}
    end
    attr_accessor :graphs

    def dup
      other = super
      other.graphs = graphs
      other
    end

    def graph_transfer
      source_rigor.graph_transfer
    end

    def post_to
      graph = ::RDF::Graph.new
      focus = GraphFocus.new(subject, graph, source_rigor) #XXX non-client version
      graphs[subject] = graph
      yield focus if block_given?
      return focus
    end

    def send_graphs
      @graphs.each_pair do |url, graph|
        graph_transfer.post(url, graph)
      end
    end
  end
end
