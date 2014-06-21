require 'webmachine'
require 'roadforest/application/route-adapter'
require 'roadforest/resource'

module RoadForest
  class Dispatcher < Webmachine::Dispatcher
    def initialize(services)
      super(method(:create_resource))
      @services = services
      @route_names = {}
      @trace_by_default = false
    end
    attr_accessor :services, :trace_by_default

    def route_for_name(name)
      @route_names.fetch(name)
    end

    def each_route(&block)
      @routes.each(&block)
    end

    def default_content_engine
      @services.default_content_engine
    end

    def path_provider
      @path_provider ||= PathProvider.new(self)
    end

    # Add a named route to the dispatcher - the 90% case is handled by passing
    # arguments in, but more control is available but manipulating the
    # RouteBinding object used to create the Route and ResourceAdapter
    #
    # @yields [RouteBinding] temporary configuration object
    def add_route(name=nil, path_spec=nil, resource_type=nil, interface_class=nil)
      binder = Application::RouteBinding.new(self)

      binder.route_name = name
      binder.path_spec = path_spec
      binder.resource_type = resource_type
      binder.interface_class = interface_class

      yield binder if block_given?

      binder.validate!

      @route_names[name] = binder.route
      @routes << binder.route
      binder.route
    end
    alias add add_route

    # @deprecated Just use add_route
    def add_untraced_route(name = nil, path_spec = nil, resource_type = nil, interface_class = nil)
      add_route(name, path_spec, resource_type, interface_class) do |binder|
        binder.trace = false
        yield binder if block_given?
      end
    end
    alias add_untraced add_untraced_route

    # @deprecated Just use add_route
    def add_traced_route(name, path_spec, resource_type, interface_class, bindings = nil, &block)
      add_route(name, path_spec, resource_type, interface_class) do |binder|
        binder.trace = true
        yield binder if block_given?
      end
    end
    alias add_traced add_traced_route
  end
end
