require 'resource/content-type/jsonld'
require 'resource/role/writable'
require 'resource/role/has-children'

module RoadForest
  module Resource
    class ReadOnly < Webmachine::Resource
      attr_accessor :model

      include ContentType::JSONLD

      def content_type_modules
        [ContentType::JSONLD]
      end

      def content_types_provided
        ContentType::types_provided(content_type_modules)
      end

      def params
        @request.path_info.merge('*' => @request.path_tokens)
      end

      def resource_exists?
        @model.exists?(params)
      end

      def generate_etag
        @model.etag(params)
      end

      def last_modified
        @model.last_modified(params)
      end

      def expires
        @model.expires(params)
      end

#      def known_methods
#        super + ["PATCH"]
#      end

      def model_supports(action)
        @model.respond_to?(action)
      end
    end

    class LeafItem < ReadOnly
      include Role::Writable
    end

    class ParentItem < ReadOnly
      include Role::HasChildren
      include Role::Writable
    end

    class List < ReadOnly
      include Role::HasChildren
    end
  end
end

module RoadForest
  class Parameters
    def initialize
      @path_info = {}
      @get_params = {}
      @remainder = []
    end
    attr_accessor :path_info, :get_params, :remainder

    def [](field_name)
      @path_info[field_name] || @get_params[field_name]
    end

    def fetch(field_name)
      @path_info[field_name] || @get_params.fetch(field_name)
    end

    def slice(*fields)
      fields.each_with_object({}) do |name, hash|
        hash[name] = self[name]
      end
    end

    def to_hash
      @get_params.merge(@path_info).merge('*' => @remainder)
    end
  end

  class Result
    attr_accessor :graph, :subject_resource

    def initialize(subject=nil, graph=nil)
      @graph, @subject_resource = graph, subject
    end
  end
end

module RoadForest
  class Model
    def initialize(services)
      @services = services
    end

    def graph_for(route_name, params)
      walker = ATST::Walker.new
      walker.start_walk(@services.router.path_for(route_name, params.to_hash)
    end

    def resource_exists?(params)

    end

    def etag(params)

    end

    def last_modified(params)

    end

    def expires(params)

    end

    #This is also "create" if there's no existing thing at "params"
    def update(params, graph)

    end

    def add_child(params, graph)

    end

    def retreive(params)

    end

    def delete(params)

    end
  end
end
