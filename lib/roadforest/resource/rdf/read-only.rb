require 'roadforest/resource/handlers'
require 'roadforest/application/parameters'

module RoadForest
  module Resource
    module RDF
      #Used for a resource that presents a read-only representation
      class ReadOnly < Webmachine::Resource
        def self.register(method_name)
          Handlers.register(method_name, self)
        end

        register :read_only

        attr_accessor :model, :trace

        ### RoadForest interface

        def params
          params = Application::Parameters.new do |params|
            params.path_info = @request.path_info
            params.query_params = @request.query_params
            params.path_tokens = @request.path_tokens
          end
        end

        def request_uri
          request.uri.to_s.sub(/[?]\Z/, '')
        end

        def request_accept_header
          request.headers["Accept"] || "*/*"
        end

        def response_content_type=(type)
          response.headers["Content-Type"] = type
        end

        def response_body=(body)
          response.body = body
        end

        def retrieve_model
          absolutize(@model.canonical_host, @model.retrieve)
        end
        alias retreive_model retrieve_model

        #      def known_methods
        #        super + ["PATCH"]
        #      end

        def model_supports(action)
          @model.respond_to?(action)
        end
        ### Webmachine interface

        def trace?
          !!@trace
        end

        #Overridden rather than metaprogram content type methods
        def send(*args)
          if args.length == 1 and not model.nil?
            model.type_handling.fetch(args.first).call(self)
          else
            super
          end
        rescue KeyError
          super
        end

        def method(name)
          if model.nil?
            super
          else
            model.type_handling.fetch(name).method(:call)
          end
        rescue KeyError
          super
        end

        def content_types_provided
          model.type_handling.renderers.type_map
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
      end
    end
  end
end
