require 'roadforest/rdf/graph-store'
require 'roadforest/remote-host'
require 'roadforest/test-support/http-client'
module RoadForest::TestSupport
  class RemoteHost < ::RoadForest::RemoteHost
    def initialize(app)
      @app = app
      super(app.canonical_host)
    end

    def build_graph_store
      RoadForest::RDF::GraphStore.new
    end

    def http_client
      @http_client ||= HTTPClient.new(@app, @url)
    end

    def http_exchanges
      http_client.exchanges
    end
  end
end
