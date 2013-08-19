require 'roadforest/resource/role/has-children'

module RoadForest
  module Resource
    module Role
      module Writable
        class IncludeOrder < StandardError; end

        def self.allowed_methods
          %w[POST PUT DELETE]
        end

        def self.included(mod)
          if mod.ancestors.include?(HasChildren)
            #Might regret this later - some kind of "I promise to fix it?"
            raise IncludeOrder, "Writable has to be included before HasChildren"
          end
        end

        def post_is_create
          true
        end

        def content_types_accepted
          model.type_handling.parsers.type_map
        end

        def request_body
          @request.body
        end

        def known_content_type(content_type)
          content_type = Webmachine::MediaType.parse(content_type)
          content_types_accepted.any?{|ct, _| content_type.match?(ct)}
        end

        def delete_resource
          @model.delete(params)
        end
      end
    end
  end
end
