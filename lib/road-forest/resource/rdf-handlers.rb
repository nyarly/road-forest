require 'road-forest/resource/content-type/jsonld'
require 'road-forest/resource/role/writable'
require 'road-forest/resource/role/has-children'
require 'road-forest/resource/handlers'
require 'road-forest/data-exchange'

module RoadForest
  module Resource
    #Used for a resource that presents a read-only representation
    class ReadOnly < Webmachine::Resource
      def self.register(method_name)
        Handlers.register(method_name, self)
      end

      register :read_only

      attr_accessor :model

      include ContentType::JSONLD

      def content_type_modules
        [ContentType::JSONLD]
      end

      def content_types_provided
        ContentType::types_provided(content_type_modules)
      end

      def params
        params = Parameters.new do |params|
          params.path_info = @request.path_info
          params.query_params = @request.query_params
          params.remainder = @request.path_tokens
        end
      end

      def resource_exists?
        @model.exists?
      end

      def generate_etag
        @model.etag
      end

      def last_modified
        @model.last_modified
      end

      def expires
        @model.expires
      end

#      def known_methods
#        super + ["PATCH"]
#      end

      def model_supports(action)
        @model.respond_to?(action)
      end
    end

    #Used for a simple resource that has properties that can be updated, but
    #doesn't have any children - for example a comment
    class LeafItem < ReadOnly
      register :leaf

      include Role::Writable

      def allowed_methods
        super + Role::Writable.allowed_methods
      end
    end

    #Used for a resource that has properties itself that can be updated, and
    #also has one or more kinds of dependent or subordinate resources - can new
    #resources be created by posting to this one? e.g. a post, which can have
    #comments
    class ParentItem < ReadOnly
      register :parent

      include Role::Writable
      include Role::HasChildren

      def allowed_methods
        (super + [Role::Writable, Role::HasChildren].map(&:allowed_methods)).uniq
      end
    end

    #Used for a resource that simply represents a list of other resources
    #without having any properties itself - a list of posts, for instance
    class List < ReadOnly
      register :list

      include Role::HasChildren

      def allowed_methods
        super + Role::HasChildren.allowed_methods
      end
    end
  end
end
