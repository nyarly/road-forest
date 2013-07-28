require 'road-forest/rdf'
require 'road-forest/rdf/update-focus'
require 'road-forest/credence-annealer'

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

      anneal(updater, &block)

      puts; puts "#{__FILE__}:#{__LINE__} => #{(target_graph.dump(:nquads))}"
      target_graph.each_context do |context|
        puts; puts "#{__FILE__}:#{__LINE__} => #{(context).inspect}"
        http_client.put(context) do |request|
          graph = ::RDF::Graph.new(context, :data => target_graph)
          request.body = render_graph(graph)
        end
      end
    end

    def getting(&block)
      reader = GraphReader.new(@graph)

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
