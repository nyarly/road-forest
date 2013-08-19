require 'roadforest/rdf/source-rigor/investigator'
class RoadForest::RDF::SourceRigor
  class NullInvestigator < Investigator
    register :null

    def pursue(investigation)
      investigation.results = []
    end
  end
end
