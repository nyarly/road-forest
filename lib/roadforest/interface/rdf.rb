require 'roadforest/interface/application'

module RoadForest
  Payload = Struct.new(:root, :graph)

  module Graph
    module Helpers
      module Focus
        def start_focus(graph = nil, resource_url=nil)
          graph ||= ::RDF::Graph.new
          access = RoadForest::Graph::WriteManager.new
          access.source_graph = graph
          focus = RoadForest::Graph::GraphFocus.new(access, resource_url || my_url)

          yield focus if block_given?
          return graph
        end
      end

      module Payloads
        include Focus

        def payload_blocks
          @payload_blocks ||= {}
        end

        def payload_block(domain, type, &block)
          payload_blocks[[domain, type]] = block
        end

        def backfill_payload(domain, type, root)
          if payload_blocks.has_key?([domain, type])
            start_focus(nil, root) do |focus|
              payload_blocks[[domain, type]][focus]
            end
          end
        end

        def payload_method(method_name, domain, type, &block)
          payload_block(domain, type, &block)
          define_method method_name do
            backfill_route = path_provider.find_route do |route|
              klass = route.interface_class
              next if klass.nil?
              next unless klass.respond_to? :domains
              next unless klass.respond_to? :types
              klass.domains.include?(domain) and klass.types.include?(type)
            end
            return nil if backfill_route.nil?

            klass = backfill_route.interface_class

            root_node = url_for(backfill_route.name) + klass.fragment_for(route_name, type)
            return Payload.new(root_node, nil)
          end
        end

        def payload_for_update(domain = nil, &block)
          payload_method(:update_payload, domain || :general, :update, &block)
        end

        def payload_for_create(domain = nil, &block)
          payload_method(:create_payload, domain || :general, :create, &block)
        end
      end
    end
  end

  module Interface
    class RDF < Application
      include Graph::Etagging
      include Graph::Helpers::Focus

      # Utility method, useful for overriding #update_payload and
      # #create_payload
      def payload_pair
        root_node = ::RDF::Node.new
        graph = ::RDF::Graph.new
        yield root_node, graph
        return Payload.new(root_node, graph)
      end

      def update(graph)
        start_focus(graph) do |focus|
          graph_update(focus)
        end
      end

      def graph_update(focus)
        fill_graph(focus)
      end

      def add_graph_child(graph)
        start_focus(graph) do |focus|
          add_child(focus)
        end
        new_graph #XXX?
      end

      def add_child(focus)
        new_graph
      end

      def retrieve
        new_graph
      end

      def fill_graph(graph)
      end

      def payload_focus(&block)
        pair = payload_pair
        return start_focus(pair.graph, pair.root, &block)
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
        self.response_data = start_focus do |focus|
          fill_graph(focus)
        end
      end
    end
  end
end
