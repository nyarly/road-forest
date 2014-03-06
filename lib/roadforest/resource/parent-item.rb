require 'roadforest/resource/read-only'
require 'roadforest/resource/role/writable'
require 'roadforest/resource/role/has-children'
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
        (super + [Role::Writable, Role::HasChildren].inject([]) do |list, mod|
          list + mod.allowed_methods
        end).uniq
      end
    end

    end
  end
end
