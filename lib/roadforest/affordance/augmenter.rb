require 'roadforest/utility/class-registry'
require 'roadforest/rdf/vocabulary'
require 'rdf'

module RoadForest
  module Affordance
    Af = RDF::Af

    class Augmenter
      attr_accessor :router

      def self.subject_augmentations_registry
        @subject_registry ||= Utility::ClassRegistry.new(self, "subject augmentation")
      end

      def self.object_augmentations_registry
        @object_registry ||= Utility::ClassRegistry.new(self, "object augmentation")
      end

      def subject_augmentations
        self.class.subject_augmentations_registry.map_classes do |klass|
          klass.new(self)
        end
      end

      def object_augmentations
        self.class.object_augmentations_registry.map_classes do |klass|
          klass.new(self)
        end
      end

      attr_accessor :canonical_uri

      def augment(graph)
        augmenting = AugmentingProcess.new(graph)

        augmenting.subject_resources(router).each do |resource|
          subject_augmentations.each do |augmentation|
            augmentation.apply(resource) do |statement|
              augmenting.target_graph << statement
            end
          end
        end

        augmenting.object_resources(router).each do |resource|
          object_augmentations.each do |augmentation|
            augmentation.apply(resource) do |statement|
              augmenting.target_graph << statement
            end
          end
        end

        augmenting.target_graph
      end
    end

    class Augmentation
      def self.register_for_subjects
        Augmenter.subject_augmentations_registry.add(self.name, self)
      end

      def self.register_for_objects
        Augmenter.object_augmentations_registry.add(self.name, self)
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

    class Remove < Augmentation
      register_for_subjects

      def apply(term)
        if term.resource.allowed_methods.include?("DELETE")
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Remove]
          yield [node, Af.target, term.uri]
        end
      end
    end

    class Links < Augmentation
      register_for_subjects
      register_for_objects

      def apply(term)
        if term.uri.host != canonical_uri.hostname
          return
        end

        case term.resource
        when Webmachine::Dispatcher::NotFoundResource
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Null]
          yield [node, Af.target, term.uri]
        else
          if term.resource.allowed_methods.include?("GET")
            embeddable = ContentHandling::MediaTypeList.build(["image/jpeg"])

            if embeddable.matches?(term.type_list)
              node = ::RDF::Node.new
              yield [node, ::RDF.type, Af.Embed]
              yield [node, Af.target, term.uri]
            else
              node = ::RDF::Node.new
              yield [node, ::RDF.type, Af.Navigate]
              yield [node, Af.target, term.uri]
            end
          end
        end
      end
    end


    class Update < Augmentation
      register_for_subjects

      def apply(term)
        if term.resource.allowed_methods.include?("PUT")
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Update]
          yield [node, Af.target, term.uri]
        end
      end
    end

    class Create < Augmentation
      register_for_subjects

      def apply(term)
        if term.resource.allowed_methods.include?("POST")
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Create]
          yield [node, Af.target, term.uri]
        end
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
          resource.content_types_provided.inject(ContentHandling::MediaTypeList.new) do |list, (type, method)|
            list.add_header_val(type)
          end
      end
    end

    class AugmentingProcess
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
