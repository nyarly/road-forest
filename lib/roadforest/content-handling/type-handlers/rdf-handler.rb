require 'roadforest/content-handling/type-handler'
require 'roadforest/graph/normalization'
module RoadForest
  module MediaType
    module Handlers
      class RDFHandler < Handler
        include Graph::Normalization

        def get_output(interface)
          graph = super
          root_uri = interface.canonical_uri

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

        def child_for_interface(interface, data)
          interface.add_graph_child(data)
          interface.processed
        end
      end
    end
  end
end
