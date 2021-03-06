require 'roadforest/source-rigor/graph-store'
require 'roadforest/remote-host'
require 'roadforest/test-support/http-client'
module RoadForest::TestSupport
  class RemoteHost < ::RoadForest::RemoteHost
    def initialize(services)
      @app = RoadForest::Application.new(services)
      super(services.canonical_host)
    end

    def build_graph_store
      RoadForest::SourceRigor::GraphStore.new
    end

    def http_client
      @http_client ||= HTTPClient.new(@app, @url)
    end

    def http_exchanges
      http_client.exchanges
    end
  end
end
