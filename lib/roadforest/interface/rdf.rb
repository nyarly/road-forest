require 'roadforest/interface/application'

module RoadForest
  module Interface
    class RDF < Application
      include RoadForest::RDF::Etagging

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
        access = RoadForest::RDF::WriteManager.new
        access.source_graph = graph
        focus = RoadForest::RDF::GraphFocus.new(access, resource_url || my_url)

        yield focus if block_given?
        return focus
      end

      def copy_interface(node, route_name, params=nil)
        params ||= {}

        url = url_for(route_name, params)
        source_interface = interface_for(route_name, params)

        access = RoadForest::RDF::CopyManager.new
        access.source_graph = source_interface.current_graph
        access.target_graph = node.access_manager.destination_graph
        copier = RoadForest::RDF::GraphFocus.new(access, url)

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
        self.response_data = graph
      end
    end
  end
end
