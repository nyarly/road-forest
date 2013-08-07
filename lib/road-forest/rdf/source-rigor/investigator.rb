require 'road-forest/utility/class-registry'

class RoadForest::RDF::SourceRigor
  class NotCredible < StandardError; end
  class NoCredibleResults < StandardError; end

  class Investigator
    extend ::RoadForest::Utility::ClassRegistry::Registrar
    def self.registry_purpose; "investigator"; end

    def pursue(investigation)
      raise NoCredibleResults
    end
  end
end
require 'road-forest/rdf/source-rigor/null-investigator'
require 'road-forest/rdf/source-rigor/http-investigator'
