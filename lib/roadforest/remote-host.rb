require 'roadforest/source-rigor'
require 'roadforest/source-rigor/credence-annealer'
require 'roadforest/source-rigor/rigorous-access'
require 'roadforest/source-rigor/graph-store' #XXX
require 'roadforest/graph/graph-focus'
require 'roadforest/graph/post-focus'
require 'roadforest/http/user-agent'
require 'roadforest/http/graph-transfer'
require 'roadforest/http/adapters/excon'

module RoadForest
  class RemoteHost
    include Graph::Normalization

    def initialize(well_known_url)
      self.url = well_known_url
    end
    attr_reader :url

    def url=(string)
      @url = normalize_resource(string)
    end

    def build_graph_store
      SourceRigor::GraphStore.new
    end

    attr_writer :http_client
    def http_client
      @http_client ||= HTTP::ExconAdapter.new(url)
    end

    def trace=(target)
      user_agent.trace = target
    end

    def user_agent
      @user_agent ||= HTTP::UserAgent.new(http_client)
    end

    def graph_transfer
      @graph_transfer ||= HTTP::GraphTransfer.new(user_agent)
    end

    def add_credentials(username, password)
      user_agent.keychain.add(url, username, password)
    end

    def source_rigor
      @source_rigor ||=
        begin
          rigor = SourceRigor.http
          rigor.graph_transfer = graph_transfer
          rigor
        end
    end

    def render_graph(graph)
      Resource::ContentType::JSONLD.from_graph(graph)
    end

    def anneal(focus)
      graph = focus.access_manager.source_graph
      annealer = SourceRigor::CredenceAnnealer.new(graph)
      annealer.resolve do
        focus.reset
        yield focus
      end
    end

    def transaction(manager_class, focus_class, &block)
      graph = build_graph_store
      access = manager_class.new
      access.rigor = source_rigor
      access.source_graph = graph
      focus = focus_class.new(access, url)

      anneal(focus, &block)

      return focus
    end

    def putting(&block)
      update = transaction(SourceRigor::UpdateManager, Graph::GraphFocus, &block)

      access = update.access_manager

      access.each_target do |context, graph|
        graph_transfer.put(context, graph)
      end
    end

    def posting(&block)
      poster = transaction(SourceRigor::PostManager, Graph::PostFocus, &block)

      poster.graphs.each_pair do |url, graph|
        graph_transfer.post(url, graph)
      end
    end

    def getting(&block)
      transaction(SourceRigor::RetrieveManager, Graph::GraphFocus, &block)
    end

    def put_file(destination, type, io)
      if destination.respond_to?(:to_context)
        destination = destination.to_context
      elsif destination.respond_to?(:to_s)
        destination = destination.to_s
      end
      response = user_agent.make_request("PUT", destination, {"Content-Type" => type}, io)
    end

    #TODO:
    #def deleting
    #def patching
  end
end
