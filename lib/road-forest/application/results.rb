require 'road-forest/application'

module RoadForest
  class Application
    #The results of processing an RDF update - could include a new graph, or a
    #different resource (url) to look at
    class Results
      attr_accessor :graph, :go_to_resource
      attr_reader :resource, :type, :body

      def initialize(resource)
        @resource = resource
      end

      def model
        resource.model
      end

      def render_data(data)
        renderer = model.type_handling.choose_renderer(resource.request_accept_header)
        @type = renderer.type
        @body = renderer.local_to_network(result.graph)
      end

      def update_resource(resource)
        if go_to_resource
          resource.redirect_to(go_to_resource)
        end
        resource.response_content_type = type.content_type_header
        resource.response_body = body
      end
    end
  end
end
