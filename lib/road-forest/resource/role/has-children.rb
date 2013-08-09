module RoadForest
  module Resource
    module Role
      module HasChildren
        def self.allowed_methods
          %w[POST]
        end

        def post_is_create
          false
        end

        def build_graph
          type, parser = services.type_handling.choose_parser(request.content_type || 'application/octet-stream')
          parser.to_graph(request.body)
        end

        def process_post
          result = add_child_graph(params, build_graph)

          if result.go_to_resource
            @response.location = result.go_to_resource
          end

          return true
        end

        def add_child_graph(params, graph)
          results = Application::Results.new(request.uri, graph)
          @model.add_child(results)
          results
        end

      end
    end
  end
end
