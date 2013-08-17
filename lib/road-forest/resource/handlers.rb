require 'road-forest/application/route-adapter'

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

      def bundle(resource_class, &block)
        Application::RouteAdapter.new(resource_class, &block)
      end

      def bundle_typed_resource(resource_type, model_class, route_name)
        resource_class = Resource::Handlers.registry.fetch(resource_type)
        bundle(resource_class) do |resource, request, response|
          resource.model = model_class.new(route_name, resource.params, services)
        end
      end

      def bundle_traced_resource(resource_type, model_class, route_name)
        resource_class = Resource::Handlers.registry.fetch(resource_type)
        bundle(resource_class) do |resource, request, response|
          resource.model = model_class.new(route_name, resource.params, services)
          resource.trace = true
        end
      end
    end
  end
end
