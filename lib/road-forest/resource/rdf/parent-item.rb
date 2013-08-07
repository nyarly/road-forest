require 'road-forest/resource/rdf/read-only'
require 'road-forest/resource/role/writable'
require 'road-forest/resource/role/has-children'
module RoadForest
  module Resource
    module RDF
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

    end
  end
end
