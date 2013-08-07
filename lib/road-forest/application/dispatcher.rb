require 'webmachine'

module RoadForest
  class Dispatcher < Webmachine::Dispatcher
    include Resource::Handlers
    def initialize(services)
      super(method(:create_resource))
      @services = services
      @route_names = {}
    end
    attr_accessor :services

    def resource_route(resource, name, path_spec, bindings)
      route = Route.new(path_spec, resource, bindings || {})
      yield route if block_given?
      @route_names[name] = route
      @routes << route
      route
    end

    def add_route(name, path_spec, resource_type, model_class, bindings = nil, &block)
      resource = bundle_typed_resource(resource_type, model_class, name)
      resource_route(resource, name, path_spec, bindings, &block)
    end
    alias add add_route

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
