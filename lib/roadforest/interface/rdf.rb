require 'roadforest/interface/application'

module RoadForest
  module Interface
    class RDF < Application
      include RoadForest::Graph::Etagging

      Payload = Struct.new(:root, :graph)

      # Utility method, useful for overriding #update_payload and
      # #create_payload
      def payload_pair
        root_node = ::RDF::Node.new
        graph = ::RDF::Graph.new
        yield root_node, graph
        return Payload.new(root_node, graph)
      end

      def update(graph)
        graph_update(start_focus(graph))
      end

      def graph_update(focus)
        fill_graph(focus)
      end

      def add_graph_child(graph)
        add_child(start_focus(graph))
        new_graph
      end

      def add_child(focus)
        new_graph
      end

      def retrieve
        new_graph
      end

      def fill_graph(graph)
      end

      def start_focus(graph, resource_url=nil)
        access = RoadForest::Graph::WriteManager.new
        access.source_graph = graph
        focus = RoadForest::Graph::GraphFocus.new(access, resource_url || my_url)

        yield focus if block_given?
        return focus
      end

      def copy_interface(node, route_name, params=nil)
        params ||= {}

        url = url_for(route_name, params)
        source_interface = interface_for(route_name, params)

        access = RoadForest::Graph::CopyManager.new
        access.source_graph = source_interface.current_graph
        access.target_graph = node.access_manager.destination_graph
        copier = RoadForest::Graph::GraphFocus.new(access, url)

        yield copier if block_given?
        copier
      end

      def etag
        @etag ||= etag_from(etag_graph)
      end

      def etag_graph
        current_graph
      end

      def current_graph
        return response_data if response_values.has_key?(:data)
        new_graph
      end

      def new_graph
        graph = ::RDF::Graph.new
        focus = start_focus(graph, my_url)
        fill_graph(focus)
        puts "\n#{__FILE__}:#{__LINE__} => \n#{graph.dump(:ntriples)}"
        self.response_data = graph
      end
    end
  end
end
