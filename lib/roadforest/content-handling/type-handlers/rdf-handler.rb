require 'roadforest/content-handling/type-handler'
require 'roadforest/rdf/normalization'
module RoadForest
  module MediaType
    module Handlers
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
    end
  end
end
