module RoadForest
  class Application
    class RouteAdapter
      def initialize(route_name, resource_class, model_class)
        @resource_class = resource_class

        @route_name = route_name
        @model_class = model_class
        @application = nil
        @trace = false
        yield self if block_given?
      end
      attr_accessor :route_name, :resource_class, :model_class, :application, :trace

      def new(request, response)
        resource = resource_class.new(request, response)
        resource.model = build_model(resource.params)
        resource.trace = trace
        resource
      end

      def build_model(params)
        model_class.new(route_name, params, application.services)
      end

      def <(klass)
        if klass <= Webmachine::Resource
          return true
        else
          return false
        end
      end
    end
  end
end
