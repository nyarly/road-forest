module RoadForest
  class Application
    #Embedded in WebMachine's Routes to compose the object structure at need
    class ResourceAdapter
      attr_accessor :resource_builder, :interface_builder, :route_name, :router, :services, :content_engine, :trace, :router

      def <(klass)
        if klass <= Webmachine::Resource
          return true
        else
          return false
        end
      end

      def new(request, response)
        resource = resource_builder.call(request, response)
        resource.interface = build_interface(resource.params)
        resource.content_engine = content_engine || router.default_content_engine
        resource.trace = trace?
        resource
      end

      def build_interface(params)
        interface_builder.call(route_name, params, router.path_provider(route_name), router.services)
      end

      def interface_class
        if interface_builder.respond_to? :interface_class
          interface_builder.interface_class
        else
          nil
        end
      end

      def trace?
        if @trace.nil?
          router.trace_by_default
        else
          !!@trace
        end
      end
    end

    #Extension of Webmachine's Routes that allows for rendering url paths and
    #parameter lists.
    class Route < Webmachine::Dispatcher::Route
      attr_accessor :name
      # Create a complete URL for this route, doing any necessary variable
      # substitution.
      # @param [Hash] vars values for the path variables
      # @return [String] the valid URL for the route
      def build_path(vars = nil)
        vars ||= {}
        vars = vars.to_hash
        vars = vars.dup
        path_spec = resolve_path_spec(vars)
        if path_spec.any?{|segment| segment.is_a?(Symbol) or segment == "*"}
          raise "Cannot build path - missing vars: #{path_spec.inspect}"
        end
        path = "/" + path_spec.join("/")
        vars.delete('*')
        unless vars.empty?
          path += "?" + vars.map do |key,value|
            [key,value].join("=")
          end.join("&")
        end
        return path
      end

      def resolve_path_spec(vars)
        path_spec.map do |segment|
          case segment
          when '*',Symbol
            if (string = vars.delete(segment)).nil?
              segment
            else
              string
            end
          when String
            segment
          end
        end
      end

      def interface_class
        if resource.respond_to? :interface_class
          resource.interface_class
        else
          nil
        end
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

    class InterfaceBuilder
      attr_reader :interface_class
      def initialize(interface_class)
        @interface_class = interface_class
      end

      def call(name, params, router, services)
        interface_class.new(name, params, router, services)
      end
    end

    class RouteBinding
      def initialize(router)
        @router = router
      end

      attr_accessor :route_name, :path_spec, :bindings, :guard
      attr_accessor :resource_type, :interface_builder, :interface_class, :services, :trace, :content_engine

      def resource_builder
        @resource_builder ||= proc do |request, response|
          Resource.get(resource_type).new(request, response)
        end
      end

      def build_resource(&block)
        @resource_builder = block
      end

      def interface_builder
        @interface_builder ||= InterfaceBuilder.new(interface_class)
      end

      def build_interface(&block)
        @interface_builder = block
      end

      def route
        @route ||=
          begin
            route =
              if guard.nil?
                Route.new(path_spec, resource_adapter, bindings || {})
              else
                Route.new(path_spec, resource_adapter, bindings || {}, &guard)
              end
            route.name = route_name
            route
          end
      end

      def resource_adapter
        @resource_adapter ||=
          begin
            ResourceAdapter.new.tap do |adapter|
              adapter.router = @router
              adapter.route_name = route_name
              adapter.interface_builder = interface_builder
              adapter.resource_builder = resource_builder
              adapter.content_engine = content_engine
              adapter.trace = trace
            end
          end
      end

      def validate!
        problems = []

        if @path_spec.nil?
          problems << "Path specification is nil - no way to route URLs here."
        end

        if @resource_builder.nil? && @resource_type.nil?
          problems << "No means provided to build a resource adapter: set resource_type or resource_builder"
        end

        if @interface_builder.nil? and @interface_class.nil?
          problems << "No means provided to build an application interface: set interface_class or interface_builder"
        end

        unless problems.empty?
          raise InvalidRouteDefinition, "Route invalid:\n  #{problems.join("  \n")}"
        end
        return true
      end
    end
  end
end
