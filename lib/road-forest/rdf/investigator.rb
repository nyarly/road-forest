module RoadForest::RDF
  class NoCredibleResults < StandardError; end
  class Investigator
    def pursue(graph_manager, results)
      raise NoCredibleResults
    end
  end

  class LiberalInvestigator
    def pursue(graph_manager, results)
      []
    end
  end
end
