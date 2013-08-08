require 'road-forest/rdf/update-focus'
require 'road-forest/rdf/source-rigor/credence-annealer'
require 'road-forest/http/graph-transfer'
require 'road-forest/http/adapters/excon'

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
      target_graph = ::RDF::Repository.new
      updater = RDF::UpdateFocus.new
      updater.source_graph = @graph
      updater.target_graph = target_graph
      updater.subject = @url
      updater.source_rigor = @graph.source_rigor
      updater.graph_transfer = graph_transfer

      anneal(updater, &block)

      target_graph.each_context do |context|
        graph = ::RDF::Graph.new(context, :data => target_graph)
        graph_transfer.put(context, graph)
      end
    end

    def getting(&block)
      reader = GraphReader.new(@graph)
      reader.source_graph = @graph
      reader.subject = @url
      reader.source_rigor = @graph.source_rigor
      reader.graph_transfer = graph_transfer

      anneal(reader, &block)
    end

    #TODO:
    #def deleting
    #def posting
    #def patching
  end
end
