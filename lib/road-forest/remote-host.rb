require 'road-forest/rdf'
require 'road-forest/rdf/update-focus'
require 'road-forest/credence-annealer'
require 'road-forest/http/graph-transfer'

module RoadForest
  class ExconAdapter

  end

  class ContentTranslater
    def initialize(graph)
      @graph = graph
    end

  end

  class RemoteHost
    def initialize(well_known_url)
      @url = ::RDF::URI.parse(well_known_url)
      @graph = build_graph_manager
    end

    def build_graph_manager
      graph_manager = RDF::GraphManager.new
      graph_manager.http_client = http_client
      return graph_manager
    end

    attr_writer :http_client
    def http_client
      @http_client ||= ExconAdapter.new
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
      annealer = CredenceAnnealer.new(@graph)
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
      updater.source_skepticism = @graph.source_skepticism
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
      reader.source_skepticism = @graph.source_skepticism
      reader.graph_transfer = graph_transfer

      anneal(reader, &block)
    end

    #TODO:
    #def deleting
    #def posting
    #def patching
  end

  #Things that have to happen:
  # * a consistent credence regime
  # * a new local graph and a focus on it
  #
  # consistent credence:
  #   The whole regime has to complete without needing investigation
  #   Try the whole thing - check if investigated?
  #     yes: redo
  #     no: done
  #
  # new local graph
  # * local graph building module
  # * builder graph references copy into the local graph from the remote
  #
  #

  class CredenceFocus < RDF::GraphFocus
    def reset_promises
    end

    def fulfill_promises
    end

    def build_graph
      graph_builder = RDF::GraphBuilder.new

      credence_block do
        yield graph_builder
      end

      return graph_builder.focus
    end
  end
end
