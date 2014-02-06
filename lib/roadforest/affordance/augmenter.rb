require 'roadforest/utility/class-registry'
require 'roadforest/rdf/vocabulary'
require 'rdf'

module RoadForest
  module Affordance
    Af = RDF::Af

    class Augmenter
      attr_accessor :router

      def augmentations
        Augmentation.map_classes do |klass|
          klass.new(self)
        end
      end

      def augment(graph)
        augmenting = AugmentingProcess.new(graph)

        augmenting.subject_resources(router).each do |resource|
          augmentations.each do |augmentation|
            augmentation.apply(resource) do |statement|
              augmenting.target_graph << statement
            end
          end
        end

        augmenting.target_graph
      end
    end

    class Augmentation
      extend Utility::ClassRegistry::Registrar

      def initialize(augmenter)
        @augmenter = augmenter
      end

      def self.map_classes
        all_names.map do |name|
          yield get(name)
        end
      end

      def router
        @augmenter.router
      end
    end

    class Remove < Augmentation
      register :remove

      def apply(term)
        if term.resource.allowed_methods.include?("DELETE")
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Remove]
          yield [node, Af.target, term.uri]
        end
      end
    end

    class Navigate < Augmentation
      register :navigate

      def apply(term)
        if term.resource.allowed_methods.include?("GET")
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Navigate]
          yield [node, Af.target, term.uri]
        end
      end
    end


    class Update < Augmentation
      register :update

      def apply(term)
        if term.resource.allowed_methods.include?("PUT")
          node = ::RDF::Node.new
          yield [node, ::RDF.type, Af.Update]
          yield [node, Af.target, term.uri]
        end
      end
    end

    class Create < Augmentation
      register :create

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
