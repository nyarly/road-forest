require 'roadforest/utility/class-registry'

class RoadForest::Graph::SourceRigor
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
require 'roadforest/graph/source-rigor/null-investigator'
require 'roadforest/graph/source-rigor/http-investigator'
