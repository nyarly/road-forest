module RoadForest
  module Resource
    module Handlers
      def self.registry
        @registry ||= {}
      end


      def self.register(handler_type, klass)
        registry[handler_type] = klass

        method_name = "#{handler_type}_model"
        define_method(method_name) do |model_class|
          if block_given?
            bundle_model(klass, model_class){|model| yield(model)}
          else
            bundle_model(klass, model_class)
          end
        end
      end

      class Handler
        def initialize(resource_class, &setup_block)
          @resource_class = resource_class
          @setup_block = setup_block
        end

        def new(request, response)
          resource = @resource_class.new(request, response)
          @setup_block[resource, request, response]
          resource
        end

        def <(klass)
          if klass <= Webmachine::Resource
            return true
          else
            return false
          end
        end
      end

      def bundle(resource_class, &block)
        Handler.new(resource_class, &block)
      end

      def bundle_model(resource_class, model_class, route_name)
        bundle(resource_class) do |resource, request, response|
          resource.model = model_class.new(route_name, resource.params, services)
        end
      end

      def bundle_typed_resource(resource_type, model_class, route_name)
        bundle_model(Resource::Handlers.registry.fetch(resource_type), model_class, route_name)
      end
    end
  end
end
