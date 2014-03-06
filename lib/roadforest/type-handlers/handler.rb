module RoadForest
  module TypeHandlers
    class Handler
      def network_to_local(base_uri, network)
        return network
      end

      def local_to_network(base_uri, local)
        return local
      end

      def parse_for(resource)
        source = resource.request_body
        interface = resource.interface
        input_data = network_to_local(interface.my_url, source)

        update_interface(interface, input_data)

        renderer = resource.content_engine.choose_renderer(resource.request_accept_header)
        body = renderer.local_to_network(interface.my_url, interface.response_data)

        build_response(resource)
      end

      def render_for(resource)
        interface = resource.interface
        output_data = get_output(interface)
        local_to_network(interface.my_url,  output_data)
      end

      def add_child_to(resource)
        interface = resource.interface
        source = resource.request_body
        input_data = network_to_local(interface.my_url, source)

        child_for_interface(resource.interface, input_data)

        build_response(resource)
      end

      def build_response(resource)
        interface = resource.interface

        renderer = resource.content_engine.choose_renderer(resource.request_accept_header)
        body = renderer.local_to_network(interface.my_url, interface.response_data)

        resource.response_content_type = renderer.content_type_header
        resource.response_body = body
        if interface.response_location
          resource.redirect_to(interface.response_location)
        end
      end

      def child_for_interface(interface, data)
        interface.add_child(data)
        interface.processed
      end

      def update_interface(interface, input_data)
        result = interface.update(input_data)
        interface.response_data = result
        interface.processed
        result
      end

      def get_output(interface)
        result = interface.retrieve
        interface.response_data = result
        interface.processed
        result
      end
    end
  end
end
