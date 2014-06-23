require 'webmachine'
require 'roadforest/application/route-adapter'
require 'roadforest/application/path-provider'
require 'roadforest/resource'

module RoadForest
  class Dispatcher < Webmachine::Dispatcher
    def initialize(services)
      super(method(:create_resource))
      @services = services
      @route_names = {}
      @route_mappings = []
      @trace_by_default = false
    end
    attr_accessor :services, :trace_by_default

    def route_for_name(name)
      @route_names.fetch(name)
    end

    def mapped_route_for_name(from, name, params)
      mapping = @route_mappings.find do |mapping|
        mapping.matches?(from, name, params)
      end

      unless mapping.nil?
        name = mapping.to_name
      end

      return route_for_name(name)
    end

    def find_route(*args)
      if block_given?
        @routes.find{|route| yield(route)}
      else
        super
      end
    end

    def each_route(&block)
      @routes.each(&block)
    end

    def each_name_and_route(&block)
      @route_names.each_pair(&block)
    end

    def default_content_engine
      @services.default_content_engine
    end

    def path_provider(route_name)
      PathProvider.new(route_name, self)
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

    def add_route_map(route_map)
      @route_mappings << route_map
    end

    class RouteMap
      class Configurator
        def initialize(name, router)
          @router = router
          @map = RouteMap.new
          @map.in_name = name
        end

        def from(name, params=nil)
          @map.from_name = name
          @map.from_params = [*params]
          self
        end

        def to(name)
          @map.to_name = name
          @router.add_route_map(@map)
          nil
        end
      end

      def initialize
      end
      attr_accessor :in_name, :from_name, :from_params, :to_name

      def matches?(in_name, name, params)
        return false unless in_name == @in_name
        return false unless name == @from_name
        return false unless @from_params.all?{|name| params.has_key?(name)}
        return true
      end
    end

    def map_in(route_name)
      RouteMap::Configurator.new(route_name, self)
    end
  end
end
