require 'webmachine'
require 'roadforest/application/route-adapter'
require 'roadforest/resource/rdf'

module RoadForest
  class Dispatcher < Webmachine::Dispatcher
    def initialize(application)
      super(method(:create_resource))
      @application = application
      @route_names = {}
      @trace_by_default = false
    end
    attr_accessor :application, :trace_by_default

    def route_for_name(name)
      @route_names.fetch(name)
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

    def resource_route(resource, name, path_spec, bindings)
      route = Route.new(path_spec, resource, bindings || {})
      yield route if block_given?
      @route_names[name] = route
      @routes << route
      route
    end

    def bundle_typed_resource(resource_type, model_class, route_name)
      resource_class = Resource.get(resource_type)
      Application::RouteAdapter.new(route_name, resource_class, model_class) do |adapter|
        adapter.application = application
      end
    end

    def bundle_traced_resource(resource_type, model_class, route_name)
      resource_class = Resource.get(resource_type)
      Application::RouteAdapter.new(route_name, resource_class, model_class) do |adapter|
        adapter.application = application
        adapter.trace = true
      end
    end

    class Route < Webmachine::Dispatcher::Route
      # Create a complete URL for this route, doing any necessary variable
      # substitution.
      # @param [Hash] vars values for the path variables
      # @return [String] the valid URL for the route
      def build_path(vars = nil)
        vars ||= {}
        "/" + path_spec.map do |segment|
          case segment
          when '*',Symbol
            vars.fetch(segment)
          when String
            segment
          end
        end.join("/")
      end

      def build_params(vars = nil)
        vars ||= {}
        params = Application::Parameters.new
        path_set = Hash[path_spec.find_all{|segment| segment.is_a? Symbol}.map{|seg| [seg, true]}]
        vars.to_hash.each do |key, value|
          if(path_set.has_key?(key))
            params.path_info[key] = value
          elsif(key == '*')
            params.path_tokens = value
          else
            params.query_params[key] = value
          end
        end
        params
      end
    end
  end
end
