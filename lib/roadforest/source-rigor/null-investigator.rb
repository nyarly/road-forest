require 'roadforest/source-rigor/investigator'

module RoadForest::SourceRigor
  class NullInvestigator < Investigator
    register :null

    def pursue(investigation)
      investigation.results = []
    end
  end
end
