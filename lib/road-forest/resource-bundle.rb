module RoadForest
  class ResourceBundle
    def initialize(resource_class, &setup_block)
      @resource_class = resource_class
      @setup_block = setup_block
    end

    def new(request, response)
      resource = @resource_class.new(request, response)
      @setup_block[resource, request, response]
      resource
    end
  end
end
