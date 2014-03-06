require 'roadforest/type-handlers/rdfa-writer/render-environment'
module RoadForest::TypeHandlers
  class RDFaWriter
    class SubjectEnvironment < RenderEnvironment
      attr_accessor :base, :predicate_terms, :property_objects, :rel, :inlist, :subject, :typeof

      def attrs
        {:rel => rel, :resource => (about || resource), :typeof => typeof, :inlist => inlist}
      end

      def is_subject?
        true
      end

      def predicates
        enum_for(:each_predicate)
      end

      def each_predicate
        predicate_terms.each do |predicate|
          predicate = RDF::URI(predicate) if predicate.is_a?(String)
          objects = property_objects[predicate.to_s]
          next if objects.nil? or objects.empty?

          nonlists, lists = objects.partition do |object|
            !_engine.is_list?(object)
          end

          add_debug {"properties with lists: #{lists} non-lists: #{nonlists}"}

          ([simple_property_env(predicate, nonlists)] + list_property_envs(predicate, lists)).compact.each do |env|
            yield(env)
          end
        end
      end

      def template_kinds
        %w{subject}
      end

      def render_checked
        return true if _engine.is_done?(subject)
        _engine.subject_done(subject)
        return false
      end

      def about
        if rel.nil?
          get_curie(subject)
        else
          nil
        end
      end

      def resource
        if rel.nil?
          nil
        else
          get_curie(subject)
        end
      end
    end
  end
end
