require 'roadforest/resource/read-only'
require 'roadforest/resource/role/writable'

module RoadForest
  module Resource
    module RDF
    #Used for a simple resource that has properties that can be updated, but
    #doesn't have any children - for example a comment
    class LeafItem < ReadOnly
      register :leaf

      include Role::Writable

      def allowed_methods
        super + Role::Writable.allowed_methods
      end
    end

    end
  end
end
