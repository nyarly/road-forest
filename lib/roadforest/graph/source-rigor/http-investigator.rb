require 'roadforest/graph/source-rigor/investigator'
module RoadForest
  class RDF::SourceRigor
    class HTTPInvestigator < Investigator
      register :http

      def pursue(investigation)
        response = investigation.make_request("GET", investigation.context_roles[:subject])
        case response
        when HTTP::GraphResponse
          investigation.insert_graph(response.url, response.graph)
        when HTTP::UnparseableResponse
          #Do nothing
        end
      end
    end
  end
end
