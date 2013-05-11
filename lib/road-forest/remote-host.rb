require 'road-forest/rdf'

module RoadForest
  class ExconAdapter

  end

  class RemoteHost
    def initialize(well_known_url)
      @url = well_known_url
      @graph = build_graph_manager
    end

    def build_graph_manager
      RDF::GraphManager.new
    end

    attr_writer :web_client
    def web_client
      @web_client ||= ExconAdapter.new
    end

    def credence_block
      focus = CredenceFocus.new
      focus.graph_manager = @graph
      focus.subject = @url

      @graph.next_impulse
      begin
        focus.reset_promises
        yield focus
      end while @graph.quiet_impulse?

      focus.fulfill_promises
    end

    def put(focus)

    end

    def post(focus)

    end

    def delete(focus)

    end

    def raw_put(focus, data, options=nil)

    end

    def raw_post(focus, data, options=nil)

    end
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

    def sub_graph
      graph_builder = GraphBuilder.new

      credence_block do
        yield graph_builder
      end

      return graph_builder.focus
    end
  end

  class GraphBuilder



  end
end
