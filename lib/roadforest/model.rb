require 'roadforest/rdf/graph-store'
module RoadForest
  class ProcessingSequenceError < StandardError
  end

  class Model
    def initialize(route_name, params, services)
      @route_name = route_name
      @params = params
      @services = services
      @data = nil
      @response_values = {}
    end
    attr_reader :route_name, :params, :services, :data

    def path_for(route_name = nil, params = nil)
      services.router.path_for(route_name, (params || self.params).to_hash)
    end

    def canonical_host
      services.canonical_host
    end

    def canonical_uri
      Addressable::URI.parse(canonical_host.to_s).join(my_path)
    end

    def type_handling
      services.type_handling
    end

    def my_path
      path_for(route_name, params)
    end

    def my_url
      canonical_uri.to_s
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

    def response_location
      @response_values.fetch(:location) do
        raise ProcessingSequenceError, "Location not available until request processed"
      end
    end

    def response_location=(location)
      @response_values[:location] = location
    end

    def response_data
      @response_values.fetch(:data) do
        raise ProcessingSequenceError, "Location not available until request processed"
      end
    end

    def response_data=(data)
      @response_values[:data] = data
    end

    def processed
      [:location, :data].each do |key|
        unless @response_values.has_key?(key)
          @response_values[key] = nil
        end
      end
    end

    def expires
      nil
    end

    def update(data)
      raise NotImplementedError
    end

    def add_child(results)
      raise NotImplementedError
    end

    def retrieve
      raise NotImplementedError
    end
    alias retreive retrieve

    def delete
      false
    end

  end

  class RDFModel < Model
    def update(graph)
      graph_update(start_focus(graph))
    end

    def graph_update(focus)
      fill_graph(focus)
    end

    def add_graph_child(graph)
      add_child(start_focus(graph))
      new_graph
    end

    def add_child(focus)
      new_graph
    end

    def retrieve
      new_graph
    end

    def fill_graph(graph)
    end

    def start_focus(graph, resource_url=nil)
      focus = RDF::GraphFocus.new
      focus.graph = graph
      focus.subject = resource_url || my_url

      yield focus if block_given?
      return focus
    end

    def start_graph(resource_url=nil, &block)
      graph = ::RDF::Graph.new
      start_focus(graph, resource_url, &block)
    end

    def new_graph
      focus = start_graph(my_url)
      fill_graph(focus)
      self.response_data = focus.graph
    end
  end
end
