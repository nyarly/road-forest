require 'road-forest/resource/rdf/read-only'
require 'road-forest/resource/role/has-children'
module RoadForest
  module Resource
    module RDF
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
end
