require 'roadforest/application/parameters'
require 'roadforest/utility/class-registry'

module RoadForest
  module Resource
    def self.registry_purpose; "resource type"; end
    extend Utility::ClassRegistry::Registrar

    module RDF #XXX This shouldn't be in RDF - resource roles are on the REST side
      #Used for a resource that presents a read-only representation
      class ReadOnly < Webmachine::Resource
        def self.register(method_name)
          RoadForest::Resource.registry.add(method_name, self)
        end

        register :read_only

        attr_accessor :interface, :trace, :content_engine

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

        def retrieve_interface
          absolutize(@interface.canonical_host, @interface.retrieve)
        end
        alias retreive_interface retrieve_interface

        #      def known_methods
        #        super + ["PATCH"]
        #      end

        def interface_supports(action)
          @interface.respond_to?(action)
        end
        ### Webmachine interface

        def trace?
          !!@trace
        end

        #Overridden rather than metaprogram content type methods
        def send(*args)
          if args.length == 1 and not interface.nil?
            content_engine.fetch(args.first).call(self)
          else
            super
          end
        rescue KeyError
          super
        end

        def method(name)
          if interface.nil?
            super
          else
            content_engine.fetch(name).method(:call)
          end
        rescue KeyError
          super
        end

        def content_types_provided
          content_engine.renderers.type_map
        rescue => ex
          super
        end

        def is_authorized?(header)
          @authorization = @interface.authorization(request.method, header)
          if(@authorization == :public || @authorization == :granted)
            return true
          end
          @interface.authentication_challenge
        end

        #XXX Add cache-control headers here
        def finish_request
        end

        def resource_exists?
          @interface.exists?
        end

        def generate_etag
          @interface.etag
        end

        def last_modified
          @interface.last_modified
        end

        def expires
          @interface.expires
        end
      end
    end
  end
end
