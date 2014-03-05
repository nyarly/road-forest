require 'roadforest/utility/class-registry'

module RoadForest::SourceRigor
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
require 'roadforest/source-rigor/null-investigator'
require 'roadforest/source-rigor/http-investigator'
