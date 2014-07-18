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
            term.resource.required_grants("DELETE").each do |grant|
              yield [node, Af.authorizedBy, grant]
            end
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
              term.resource.required_grants("GET").each do |grant|
                yield [node, Af.authorizedBy, grant]
              end
            end
          end
        end
      end

      class PayloadAugmentation < Augmentation
        def get_payload(resource)

        end

        def applicable?(resource)

        end

        def affordance_type

        end

        def applicable?(resource)
          resource.allowed_methods.include?(http_method)
        end

        def apply(term)
          resource = term.resource
          if applicable?(resource)
            node = ::RDF::Node.new
            yield [node, ::RDF.type, affordance_type]
            yield [node, Af.target, term.uri]
            term.resource.required_grants(http_method).each do |grant|
              yield [node, Af.authorizedBy, grant]
            end

            payload = get_payload(resource)
            unless payload.nil?
              yield [node, Af.payload, payload.root]
              unless payload.graph.nil?
                payload.graph.each_statement do |stmt|
                  yield stmt
                end
              end
            end
          end
        end
      end

      class Update < PayloadAugmentation
        register_for_subjects

        def get_payload(resource)
          resource.interface.update_payload
        end

        def http_method
          "PUT"
        end

        def affordance_type
          Af.Update
        end
      end

      class Create < PayloadAugmentation
        register_for_subjects

        def get_payload(resource)
          resource.interface.create_payload
        end

        def http_method
          "POST"
        end

        def affordance_type
          Af.Create
        end
      end
    end
  end
end
