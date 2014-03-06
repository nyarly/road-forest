require 'roadforest/type-handlers/rdfa-writer/render-environment'
module RoadForest::TypeHandlers
  class RDFaWriter
    class PropertyEnvironment < RenderEnvironment
      attr_accessor :object_terms, :predicate, :inlist

      def objects
        enum_for(:each_object)
      end

      def each_object
        object_terms.each do |term|
          env = object_env(predicate, term)
          env.inlist = inlist
          yield(env)
        end
      end

      def object
        objects.first
      end

      def property
        get_curie(predicate)
      end

      def rel
        get_curie(predicate)
      end

      def template_kinds
        if objects.to_a.length > 1
          %w{property-values}
        else
          %w{property-value property-values}
        end
      end
    end
  end
end
