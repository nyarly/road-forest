module RoadForest
  class Model
    def initialize(route_name, params, services)
      @route_name = route_name
      @params = params
      @services = services
      @data = nil
    end
    attr_reader :route_name, :params, :services, :data

    def path_for(route_name = nil, params = nil)
      services.router.path_for(route_name, (params || self.params).to_hash)
    end

    def my_path
      path_for(route_name, params)
    end

    def reset
    end

    def exists?
      !data.nil?
    end

    def etag
      nil
    end

    def last_modified
      nil
    end

    def expires
      nil
    end

    def new_results
      results = Results.new
      yield results if block_given?
      return results
    end

    def update(graph)
      new_results
    end

    def add_child(graph)
      new_results
    end

    def retreive
      new_results
    end

    def delete
      false
    end
  end
end
