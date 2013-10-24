require 'roadforest/rdf/source-rigor'
require 'roadforest/rdf/source-rigor/credence-annealer'
require 'roadforest/rdf/graph-store'
require 'roadforest/http/graph-transfer'
require 'roadforest/http/adapters/excon'

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
      graph = build_graph_store
      access = RDF::UpdateManager.new
      access.rigor = source_rigor
      access.source_graph = graph
      updater = RDF::GraphFocus.new(access, url)
      annealer = RDF::SourceRigor::CredenceAnnealer.new(graph)

      annealer.resolve do
        access.target_graph = ::RDF::Repository.new
        yield updater
      end

      target_graph = access.target_graph
      target_graph.each_context do |context|
        graph = ::RDF::Graph.new(context, :data => target_graph)
        graph_transfer.put(context, graph)
      end
    end

    def posting(&block)
      require 'roadforest/rdf/post-focus'
      graph = build_graph_store
      access = RDF::PostManager.new
      access.rigor = source_rigor
      access.source_graph = graph
      poster = RDF::PostFocus.new(access, url)
      graphs = {}
      poster.graphs = graphs

      anneal(poster, &block)

      graphs.each_pair do |url, graph|
        graph_transfer.post(url, graph)
      end
    end

    def getting(&block)
      graph = build_graph_store
      access = RDF::ReadOnlyManager.new
      access.rigor = source_rigor
      access.source_graph = graph
      reader = RDF::GraphReading.new(access, url)

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
