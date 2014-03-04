require 'rdf'
require 'roadforest/utility/class-registry'

module RoadForest
  module Augment
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
        augmenting = Augment::Process.new(graph)

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
  end
end
