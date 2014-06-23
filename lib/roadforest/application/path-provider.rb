module RoadForest
  class PathProvider
    def initialize(route_name, dispatcher)
      @route_name = route_name
      @dispatcher = dispatcher
    end

    def services
      @dispatcher.services
    end

    def route_for_name(name, params=nil)
      @dispatcher.mapped_route_for_name(@route_name, name, params)
    end

    # Get the URL to the given resource, with optional variables to be used
    # for bindings in the path spec.
    # @param [Webmachine::Resource] resource the resource to link to
    # @param [Hash] vars the values for the required path variables
    # @raise [RuntimeError] Raised if the resource is not routable.
    # @return [String] the URL
    def path_for(name, vars = nil)
      vars ||= {}
      route = route_for_name(name)
      ::RDF::URI.parse(route.build_path(vars))
    end

    def find_route(&block)
      @dispatcher.find_route(&block)
    end

    def each_name_and_route(&block)
      @dispatcher.each_name_and_route(&block)
    end

    def url_for(route_name, params = nil)
      ::RDF::URI.new(Addressable::URI.parse(services.canonical_host.to_s).join(path_for(route_name, params)))
    end

    def request_for(name, vars = nil)
      url = path_for(name, vars) #full url?

      Webmachine::Request.new(method, url, headers, body)
    end

    def interface_for(name, vars = nil)
      route = route_for_name(name)
      params = route.build_params(vars)
      route.resource.build_interface(params)
    end
  end
end
