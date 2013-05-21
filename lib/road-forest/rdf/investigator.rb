module RoadForest::RDF
  class NoCredibleResults < StandardError; end
  class Investigator
    def pursue(results)
      raise NoCredibleResults
    end
  end

  class NullInvestigator
    def pursue(results)
      results.empty_result
    end
  end

  class HTTPInvestigator
    def pursue(results)
      document = results.http_client.get(results.context_roles[:subject])
      case document.code
      when (200..299)
        results.graph_manager.insert_document(document)
        results = results.requery
      when (300..399)
        #client should follow redirects
      when (400..499)
      when (500..599)
        raise NotCredible #hrm
      end
      return results
    rescue NotCredible
      return results
    end
  end
end
