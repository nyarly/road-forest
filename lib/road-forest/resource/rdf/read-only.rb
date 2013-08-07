require 'road-forest/resource/handlers'
require 'road-forest/application/parameters'

module RoadForest
  module Resource
    module RDF
      #Used for a resource that presents a read-only representation
      class ReadOnly < Webmachine::Resource
        def self.register(method_name)
          Handlers.register(method_name, self)
        end

        register :read_only

        attr_accessor :model, :services
        attr_accessor :trace

        def trace?
          !!@trace
        end

        #Overridden rather than metaprogram content type methods
        def send(*args)
          if args.length == 1 and not services.nil?
            services.type_handling.fetch(args.first).call(self)
          else
            super
          end
        rescue KeyError
          super
        end

        def method(name)
          if services.nil?
            super
          else
            services.type_handling.fetch(name).method(:call)
          end
        rescue KeyError
          super
        end

        def content_types_provided
          services.type_handling.renderers.type_map
        end

        def provide_type(handler)
          handler.from_graph(retreive_model)
        end

        def params
          params = Application::Parameters.new do |params|
            params.path_info = @request.path_info
            params.query_params = @request.query_params
            params.path_tokens = @request.path_tokens
          end
        end

        def render_to_body(result_graph)
          type, renderer = services.type_handling.choose_renderer(request["Accept"])
          response.headers["Content-Type"] = type.content_type_header
          response.body = renderer.from_graph(result_graph)
        end

        def resource_exists?
          @model.exists?
        end

        def generate_etag
          @model.etag
        end

        def last_modified
          @model.last_modified
        end

        def expires
          @model.expires
        end

        def retrieve_model
          results = @model.retrieve
          results.absolutize(@model.canonical_host)
          results.graph
        end
        alias retreive_model retrieve_model

        #      def known_methods
        #        super + ["PATCH"]
        #      end

        def model_supports(action)
          @model.respond_to?(action)
        end
      end
    end
  end
end
