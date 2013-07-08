require 'road-forest/rdf'

module RoadForest
  class ExconAdapter

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

    def credence_block
      focus = CredenceFocus.new
      focus.graph_manager = @graph
      focus.subject = @url

      begin
        @graph.next_impulse
        focus.reset_promises
        yield focus
      end until @graph.quiet_impulse?

      focus.fulfill_promises
    end

    def render_graph(graph)

    end

    def putting
      target_graph = ::RDF::Graph.new
      updater = UpdateCollector.new(@graph, target_graph)

      annealer = CredenceAnnealer.new(@graph)
      annealer.resolve do
        yield updater
      end

      target_graph.each_context do |context|
        http_client.put(context) do |request|
          graph = ::RDF::Graph.new(context, :data => target_graph)
          request.body = render_graph(graph)
        end
      end
    end

    def getting
      reader = GraphReader.new(@graph)
      annealer = CredenceAnnealer.new(@graph)
      annealer.resolve do
        yield reader
      end
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
