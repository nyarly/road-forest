require 'roadforest/content-handling/type-handlers/rdfa-writer/render-environment'
module RoadForest::MediaType
  class RDFaWriter
    class ObjectEnvironment < RenderEnvironment
      attr_accessor :predicate, :object, :inlist, :element

      def simple_attrs
        {:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object), :inlist => inlist}
      end

      alias attrs simple_attrs

      def template_kinds
        %w{object}
      end

      def literal?
        object.literal?
      end
    end

    class NilObjectEnvironment < ObjectEnvironment
      def attrs
        {:rel => get_curie(predicate), :inlist => ''}
      end

      def template_kinds
        %w{nil-object object}
      end
    end

    class NodeObjectEnvironment < ObjectEnvironment
      def attrs
        {:property => get_curie(predicate), :resource => get_curie(object), :inlist => inlist}
      end

      def template_kinds
        %w{node-object object}
      end
    end

    class UriObjectEnvironment < ObjectEnvironment
      def attrs
        {}
      end

      def template_kinds
        %w{uri-object object}
      end
    end

    class XMLLiteralObjectEnvironment < ObjectEnvironment
      def attrs
        {:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_curie(object.datatype), :inlist => inlist}
      end

      def template_kinds
        %w{xml-literal-object object}
      end
    end
  end
end
