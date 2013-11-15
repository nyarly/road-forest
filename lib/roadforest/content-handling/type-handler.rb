module RoadForest
  module MediaType
    module Handlers
      class Handler
        def network_to_local(base_uri, network)
          return network
        end

        def local_to_network(base_uri, local)
          return local
        end

        def parse_for(resource)
          source = resource.request_body
          model = resource.model
          input_data = network_to_local(model.my_url, source)

          update_model(model, input_data)

          renderer = model.type_handling.choose_renderer(resource.request_accept_header)
          body = renderer.local_to_network(model.my_url, model.response_data)

          build_response(resource)
        end

        def render_for(resource)
          model = resource.model
          output_data = get_output(model)
          local_to_network(model.my_url,  output_data)
        end

        def add_child_to(resource)
          model = resource.model
          source = resource.request_body
          input_data = network_to_local(model.my_url, source)

          child_for_model(resource.model, input_data)

          build_response(resource)
        end

        def build_response(resource)
          model = resource.model

          renderer = model.type_handling.choose_renderer(resource.request_accept_header)
          body = renderer.local_to_network(model.my_url, model.response_data)

          resource.response_content_type = renderer.content_type_header
          resource.response_body = body
          if model.response_location
            resource.redirect_to(model.response_location)
          end
        end

        def child_for_model(model, data)
          model.add_child(data)
          model.processed
        end

        def update_model(model, input_data)
          result = model.update(input_data)
          model.response_data = result
          model.processed
          result
        end

        def get_output(model)
          result = model.retrieve
          model.response_data = result
          model.processed
          result
        end
      end
    end
  end
end
