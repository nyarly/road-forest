#@require 'rdf/rdfa' #XXX Otherwise json-ld grabs RDFa documents. Awaiting fix
#upstream
require 'json/ld'

module RoadForest
  module MediaType
    module Handlers
      module Wrap
        class Render
          def initialize(handler)
            @handler = handler
          end

          def local_to_network(network)
            @handler.local_to_network(network)
          end
          alias from_graph local_to_network

          def call(resource)
            local_to_network(resource.retreive_model)
          end
        end

        class Parse
          def initialize(handler)
            @handler = handler
          end

          def network_to_local(source)
            @handler.network_to_local(source)
          end
          alias to_graph network_to_local

          def call(resource)
            source = resource.request_body
            graph = network_to_local(source)
            result_graph = resource.accept_graph(graph)
            resource.render_to_body(result_graph)
          end
        end
      end

      class JSONLD
        def content_types
          ["application/ld+json"]
        end

        def local_to_network(rdf)
          JSON::LD::Writer.buffer do |writer|
            rdf.each_statement do |statement|
              writer << statement
            end
          end
        end

        def network_to_local(source)
          graph = ::RDF::Graph.new
          reader = JSON::LD::Reader.new(source)
          reader.each_statement do |statement|
            graph.insert(statement)
          end
          graph
        end
      end
    end
  end
end
