require 'roadforest/rdf/source-rigor/investigator'
class RoadForest::RDF::SourceRigor
  class HTTPInvestigator < Investigator
    register :http

    def pursue(investigation)
      response = investigation.make_request("GET", investigation.context_roles[:subject])
      case response.status
      when (200..299)
        investigation.insert_graph(response.url, response.graph)
      when (300..399)
        #client be should following redirects
      when (400..499)
        #explicit "empty result" ?
      when (500..599)
        raise NotCredible #hrm
      end
    end
  end
end
