require 'roadforest/rdf/graph-focus'
require 'roadforest/rdf/parcel'

module RoadForest::RDF
  class UpdateFocus < GraphWriting
    def target_graph
      @access_manager.target_graph
    end

    def target_graph=(graph)
      @access_manager.target_graph = graph
    end

    def relevant_prefixes
      super.merge(relevant_prefixes_for_graph(target_graph))
    end
  end
end
