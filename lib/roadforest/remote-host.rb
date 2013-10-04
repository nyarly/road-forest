require 'roadforest/rdf/source-rigor'
require 'roadforest/rdf/source-rigor/credence-annealer'
require 'roadforest/http/graph-transfer'
require 'roadforest/http/adapters/excon'
require 'roadforest/rdf/graph-store'

module RoadForest
  class RemoteHost
    include RDF::Normalization

    def initialize(well_known_url)
      self.url = well_known_url
    end
    attr_reader :url

    def url=(string)
      @url = normalize_resource(string)
    end

    def build_graph_store
      RDF::GraphStore.new
    end

    attr_writer :http_client
    def http_client
      @http_client ||= HTTP::ExconAdapter.new(url)
    end

    def graph_transfer
      @graph_transfer ||= HTTP::GraphTransfer.new.tap do |transfer|
        transfer.http_client = http_client
      end
    end

    def source_rigor
      @source_rigor ||=
        begin
          rigor = RDF::SourceRigor.http
          rigor.graph_transfer = graph_transfer
          rigor
        end
    end

    def render_graph(graph)
      Resource::ContentType::JSONLD.from_graph(graph)
    end

    def anneal(focus)
      graph = build_graph_store
      annealer = RDF::SourceRigor::CredenceAnnealer.new(graph)
      annealer.resolve do
        yield focus
      end
    end

    def putting(&block)
      require 'roadforest/rdf/update-focus'
      graph = build_graph_store
      updater = RDF::UpdateFocus.new(url, graph, source_rigor)
      annealer = RDF::SourceRigor::CredenceAnnealer.new(graph)

      annealer.resolve do
        updater.target_graph = ::RDF::Repository.new
        yield updater
      end

      target_graph = updater.target_graph
      target_graph.each_context do |context|
        graph = ::RDF::Graph.new(context, :data => target_graph)
        graph_transfer.put(context, graph)
      end
    end

    def posting(&block)
      require 'roadforest/rdf/post-focus'
      graph = build_graph_store
      poster = RDF::PostFocus.new(url, graph, source_rigor)

      anneal(poster, &block)

      poster.send_graphs
    end

    def getting(&block)
      graph = build_graph_store
      reader = RDF::GraphReading.new(url, graph, source_rigor)

      anneal(reader, &block)
    end

    def put_file(destination, type, io)
      if destination.respond_to?(:to_context)
        destination = destination.to_context
      elsif destination.respond_to?(:to_s)
        destination = destination.to_s
      end
      request = HTTP::Request.new("PUT", destination)
      request.body = io
      request.headers["Content-Type"] = type
      response = http_client.do_request request
    end

    #TODO:
    #def deleting
    #def patching
  end
end
