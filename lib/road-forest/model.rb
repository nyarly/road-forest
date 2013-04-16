module RoadForest
  class Model
    def initialize(services)
      @memoized_data = Hash.new{|h,k| h[k] = find_data(params)}
      @services = services
    end

    def graph_for(route_name, params)
      walker = ATST::Walker.new
      walker.start_walk(@services.router.path_for(route_name, params.to_hash)
    end

    def find_data(params)
      nil
    end

    def data_for(params)
      @memoized_data[params]
    end

    def resource_exists?(params)
      !data_for(params).nil?
    end

    def etag(params)
      nil
    end

    def last_modified(params)
      nil
    end

    def expires(params)
      nil
    end

    #This is also "create" if there's no existing thing at "params"
    def update(params, graph)
      Results.new
    end

    def add_child(params, graph)
      Results.new
    end

    def retreive(params)
      Results.new
    end

    def delete(params)
      false
    end
  end
end
