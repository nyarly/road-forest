require 'road-forest/rdf/source-rigor/investigator'
class RoadForest::RDF::SourceRigor
  class HTTPInvestigator < Investigator
    register :http

    def pursue(investigation)
      response = investigation.make_request("GET", investigation.context_roles[:subject])
      case response.status
      when (200..299)
        investigation.insert_graph(response.url, response.graph)
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
