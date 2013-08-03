#@require 'rdf/rdfa' #XXX Otherwise json-ld grabs RDFa documents. Awaiting fix
#upstream
require 'json/ld'

module RoadForest
  module MediaType
    module Handlers
      module JSONLD
        def self.content_types
          ["application/ld+json"]
        end

        class Render
          def from_graph(rdf)
            JSON::LD::Writer.buffer do |writer|
              rdf.each_statement do |statement|
                writer << statement
              end
            end
          end

          def call(resource)
            #puts; puts "#{__FILE__}:#{__LINE__} =>
            ##{(rdf.graph_dump(:ntriples)).inspect}"
            from_graph(resource.retreive_model)
          end
        end

        class Parse
          def to_graph(source)
            graph = ::RDF::Graph.new
            reader = JSON::LD::Reader.new(source)
            reader.each_statement do |statement|
              graph.insert(statement)
            end
            graph
          end

          def call(resource)
            source = resource.request_body
            graph = to_graph(source)
            result_graph = resource.accept_graph(graph)
            resource.render_to_body(result_graph)
          end
        end
      end
    end
  end
end
