module RoadForest::RDF
  class NoCredibleResults < StandardError; end
  class Investigator
    def pursue(investigation)
      raise NoCredibleResults
    end
  end

  class NullInvestigator
    def pursue(investigation)
      investigation.results = []
    end
  end

  class HTTPInvestigator
    def pursue(investigation)
      document = investigation.http_client.get(investigation.context_roles[:subject])
      case document.code
      when (200..299)
        investigation.graph_manager.insert_document(document)
      when (300..399)
        #client should follow redirects
      when (400..499)
      when (500..599)
        raise NotCredible #hrm
      end
    rescue NotCredible
    end
  end
end
