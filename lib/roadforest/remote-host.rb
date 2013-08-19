require 'roadforest/rdf/source-rigor'
require 'roadforest/rdf/source-rigor/credence-annealer'
require 'roadforest/http/graph-transfer'
require 'roadforest/http/adapters/excon'

module RoadForest
  class RemoteHost
    def initialize(well_known_url)
      @url = ::RDF::URI.parse(well_known_url)
      @graph = build_graph_store
    end

    def build_graph_store
      graph_store = RDF::GraphStore.new
      graph_store.http_client = http_client
      return graph_store
    end

    attr_writer :http_client
    def http_client
      @http_client ||= HTTP::ExconAdapter.new
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
      annealer = RDF::SourceRigor::CredenceAnnealer.new(@graph)
      annealer.resolve do
        yield focus
      end
    end

    def putting(&block)
      require 'roadforest/rdf/update-focus'
      target_graph = ::RDF::Repository.new
      updater = RDF::UpdateFocus.new(@url, @graph, source_rigor)
      updater.target_graph = target_graph

      anneal(updater, &block)

      target_graph.each_context do |context|
        graph = ::RDF::Graph.new(context, :data => target_graph)
        graph_transfer.put(context, graph)
      end
    end

    def posting(&block)
      require 'roadforest/rdf/post-focus'
      poster = RDF::PostFocus.new(@url, @graph, source_rigor)

      anneal(poster, &block)

      poster.send_graphs
    end

    def getting(&block)
      reader = RDF::GraphReading.new(@url, @graph, source_rigor)

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
