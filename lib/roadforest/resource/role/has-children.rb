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

        def process_post
          parser = content_engine.choose_parser(request.content_type || 'application/octet-stream')

          parser.add_child(self)
          return true
        end
      end
    end
  end
end
