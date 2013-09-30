require 'webmachine'

module RoadForest
  class Dispatcher < Webmachine::Dispatcher
    include Resource::Handlers
    def initialize(services)
      super(method(:create_resource))
      @services = services
      @route_names = {}
      @trace_by_default = false
    end
    attr_accessor :services, :trace_by_default

    def resource_route(resource, name, path_spec, bindings)
      route = Route.new(path_spec, resource, bindings || {})
      yield route if block_given?
      @route_names[name] = route
      @routes << route
      route
    end

    def add_route(name, path_spec, resource_type, model_class, bindings = nil, &block)
      if trace_by_default
        return add_traced_route(name, path_spec, resource_type, model_class, bindings, &block)
      else
        return add_untraced_route(name, path_spec, resource_type, model_class, bindings, &block)
      end
    end
    alias add add_route

    def add_untraced_route(name, path_spec, resource_type, model_class, bindings = nil, &block)
      resource = bundle_typed_resource(resource_type, model_class, name)
      resource_route(resource, name, path_spec, bindings, &block)
    end
    alias add_untraced add_untraced_route

    def add_traced_route(name, path_spec, resource_type, model_class, bindings = nil, &block)
      resource = bundle_traced_resource(resource_type, model_class, name)
      resource_route(resource, name, path_spec, bindings, &block)
    end
    alias add_traced add_traced_route

    def route_for_name(name)
      @route_names.fetch(name)
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
