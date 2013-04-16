module RoadForest
  class PathProvider
    def initialize(dispatcher)
      @dispatcher = dispatcher
    end

    # Get the URL to the given resource, with optional variables to be used
    # for bindings in the path spec.
    # @param [Webmachine::Resource] resource the resource to link to
    # @param [Hash] vars the values for the required path variables
    # @raise [RuntimeError] Raised if the resource is not routable.
    # @return [String] the URL
    def path_for(name, vars = {})
      route = @dispatcher.route_for_name(name)
      route.build_path(vars)
    end
  end
end
