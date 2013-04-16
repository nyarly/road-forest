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
          content_type = Webmachine::MediaType.parse(request.content_type || 'application/octet-stream')
          handler_module = rdf_modules.find{|mod| mod.content_types.any?{|type| content_type.match?}}
          handler_module.to_graph(request.body)
        end

        def process_post
          @model.add_child(params, build_graph)
          return true
        end
      end
    end
  end
end
