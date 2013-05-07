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
      graph_manager.insert_document(document)
      results.requery
    rescue NotCredible
      return []
    end
  end
end
