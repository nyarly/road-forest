require 'roadforest/augment/augmentation'
require 'roadforest/graph/vocabulary'

module RoadForest
  module Augment
    module Affordance
      Af = Graph::Af

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
    end
  end
end
