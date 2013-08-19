#@require 'rdf/rdfa' #XXX Otherwise json-ld grabs RDFa documents. Awaiting fix
#upstream
require 'json/ld'

module RoadForest
  module MediaType
    module Handlers
      module Wrap
        class Wrapper
          def initialize(type, handler)
            @type = type
            @handler = handler
          end
          attr_reader :type, :handler

          def local_to_network(network)
            @handler.local_to_network(network)
          end
          alias from_graph local_to_network

          def network_to_local(source)
            @handler.network_to_local(source)
          end
          alias to_graph network_to_local
        end

        class Render < Wrapper
          def call(resource)
            @handler.render_for(resource)
          end

          def content_type_header
            @type.content_type_header
          end
        end

        class Parse < Wrapper
          def call(resource)
            @handler.parse_for(resource)
          end

          def add_child(resource)
            @handler.add_child_to(resource)
          end
        end
      end

      class Handler
        def network_to_local(network)
          return network
        end

        def local_to_network(local)
          return local
        end

        def parse_for(resource)
          source = resource.request_body
          input_data = network_to_local(source)
          model = resource.model

          update_model(model, input_data)

          renderer = model.type_handling.choose_renderer(resource.request_accept_header)
          body = renderer.local_to_network(model.response_data)

          build_response(resource)
        end

        def render_for(resource)
          model = resource.model
          output_data = get_output(model)
          local_to_network(output_data)
        end

        def add_child_to(resource)
          model = resource.model
          source = resource.request_body
          input_data = network_to_local(source)

          child_for_model(resource.model, input_data)

          build_response(resource)
        end

        def build_response(resource)
          model = resource.model

          renderer = model.type_handling.choose_renderer(resource.request_accept_header)
          body = renderer.local_to_network(model.response_data)

          resource.response_content_type = renderer.content_type_header
          resource.response_body = body
          if model.response_location
            resource.redirect_to(model.response_location)
          end
        end

        def child_for_model(model, data)
          model.add_child(data)
          model.processed
        end

        def update_model(model, input_data)
          result = model.update(input_data)
          model.response_data = result
          model.processed
          result
        end

        def get_output(model)
          result = model.retrieve
          model.response_data = result
          model.processed
          result
        end
      end

require 'roadforest/rdf/normalization'
      class RDFHandler < Handler
        include RDF::Normalization

        def get_output(model)
          graph = super
          root_uri = model.canonical_uri

          graph.each_statement do |statement|
            original = statement.dup
            if ::RDF::URI === statement.subject and statement.subject.relative?
              statement.subject = normalize_resource(root_uri.join(statement.subject))
            end

            if ::RDF::URI === statement.object and statement.object.relative?
              statement.object = normalize_resource(root_uri.join(statement.object))
            end

            if statement != original
              graph.delete(original)
              graph.insert(statement)
            end
          end
          graph
        end

        def child_for_model(model, data)
          model.add_graph_child(data)
          model.processed
        end
      end

      #application/ld+json
      class JSONLD < RDFHandler
        def local_to_network(rdf)
          JSON::LD::Writer.buffer do |writer|
            rdf.each_statement do |statement|
              writer << statement
            end
          end
        end

        def network_to_local(source)
          graph = ::RDF::Graph.new
          reader = JSON::LD::Reader.new(source.to_s)
          reader.each_statement do |statement|
            graph.insert(statement)
          end
          graph
        end
      end
    end
  end
end
