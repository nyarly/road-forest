require 'road-forest/application/results'

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

    def canonical_host
      services.canonical_host
    end

    def my_path
      path_for(route_name, params)
    end

    def my_url
      Addressable::URI.parse(canonical_host.to_s).join(my_path).to_s
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

    def fill_graph(graph)
    end

    def fill_results(results)
      fill_graph(results.start_graph(my_url))
    end

    def new_results
      results = Application::Results.new
      fill_results(results)
      return results
    end

    def update(graph)
      new_results
    end

    def add_child(results)
      new_results
    end

    def retrieve
      new_results
    end
    alias retreive retrieve

    def delete
      false
    end
  end

  class FileModel < Model
  end
end
