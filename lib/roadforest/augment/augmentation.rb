require 'roadforest/augment/augmenter'
module RoadForest
  module Augment
    class Augmentation
      class << self
        def register_for_subjects
          Augmenter.subject_augmentations_registry.add(self.name, self)
        end

        def subject_precedes(other)
          Augmenter.subject_augmentations_registry.seq(self.name, other)
        end

        def subject_follows(other)
          Augmenter.subject_augmentations_registry.seq(other, self.name)
        end

        def register_for_objects
          Augmenter.object_augmentations_registry.add(self.name, self)
        end

        def object_precedes(other)
          Augmenter.object_augmentations_registry.seq(self.name, other)
        end

        def object_follows(other)
          Augmenter.object_augmentations_registry.seq(other, self.name)
        end
      end

      def initialize(augmenter)
        @augmenter = augmenter
      end

      def canonical_uri
        @augmenter.canonical_uri
      end

      def router
        @augmenter.router
      end
    end

    class LazyResource
      def initialize(uri, router)
        @uri = uri
        @router = router
      end

      attr_accessor :uri, :router

      def request
        @request ||= Webmachine::Request.new("GET", uri, {}, nil)
      end

      def response
        @response ||= Webmachine::Response.new
      end

      def route
        @route ||= router.find_route(request)
      end

      def resource
        @resource ||= router.find_resource(request, response)
      end

      def type_list
        @type_list ||=
          resource.content_types_provided.inject(ContentHandling::MediaTypeList.new) do |list, (type, _)|
            list.add_header_val(type)
          end
      end
    end

    class Process
      attr_accessor :base_graph, :subjects

      def initialize(base_graph)
        @base_graph = base_graph
      end

      def target_graph
        @target_graph ||=
          begin
            ::RDF::Repository.new.tap do |graph|
              base_graph.each_statement do |stmt|
                graph << stmt
              end
            end
          end
      end

      def subjects
        @subjects ||= base_graph.subjects.select{|obj| ::RDF::URI === obj }
      end

      def objects
        @objects ||= base_graph.objects.select{|obj| ::RDF::URI === obj}
      end

      def subject_resources(router)
        subjects.map do |uri|
          LazyResource.new(uri, router)
        end
      end

      def object_resources(router)
        objects.map do |uri|
          LazyResource.new(uri, router)
        end
      end
    end
  end
end
