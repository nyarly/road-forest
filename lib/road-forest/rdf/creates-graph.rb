module RoadForest::RDF
  module CreatesGraph
    def new_graph(uri)
      manager = GraphManager.new
      manager.start(uri)
    end
  end
end
