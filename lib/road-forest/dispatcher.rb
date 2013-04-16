module RoadForest
  class Dispatcher < Webmachine::Dispatcher
    def initialize
      super(method(:create_resource))
      @route_names = {}
    end

    def add_route(name, *args, &block)
      route = Route.new(*args, &block)
      @route_names[name] = route
      route
    end
    alias add add_route

    def route_for_name(name)
      @route_names.fetch(name)
    end

    def bundle(resource_class, &block)
      ResourceBundle.new(resource_class, &block)
    end

    def bundle_model(resource_class, model_class)
      bundle(resource_class) do |resource, request, response|
        resource.model = model_class.new(services)
      end
    end

    class Route < Webmachine::Dispatcher::Route
      # Create a complete URL for this route, doing any necessary variable
      # substitution.
      # @param [Hash] vars values for the path variables
      # @return [String] the valid URL for the route
      def build_path(vars = {})
        "/" + path_spec.map do |segment|
          case segment
          when '*',Symbol
            vars.fetch(segment)
          when String
            segment
          end
        end.join("/")
      end
    end
  end
end
