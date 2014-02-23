module RoadForest
  class Application
    class RouteAdapter
      def initialize(router)
        @router = router
      end

      attr_accessor :route_name, :resource_type, :interface_class, :services, :trace


      def <(klass)
        if klass <= Webmachine::Resource
          return true
        else
          return false
        end
      end


      def initialize(route_name, resource_class, interface_class)
        @resource_class = resource_class

        @route_name = route_name
        @interface_class = interface_class
        @application = nil
        @trace = false
        yield self if block_given?
      end
      attr_accessor :route_name, :resource_class, :interface_class, :application, :trace

      # WebMachine expects a Resource class on the end of a dispatcher route,
      # but we need to assemble the resource based on the composition of the
      # interface and resource role, so #new does that composition and returns the
      # newly created resource - Ruby classes are in fact their object
      # factories.
      def new(request, response)
        resource = build_resource(request, response)
        resource.interface = build_interface(resource.params)
        resource.trace = trace
        resource
      end

      def build_resource(request, response)
        resource_class.new(request, response)
      end

      def build_interface(params)
        interface_class.new(route_name, params, application.services)
      end

    end
  end
end
