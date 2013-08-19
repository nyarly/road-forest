module RoadForest
  module MediaType
    module Handlers
      class FileStorage
        def local_to_network(rdf)
          File::read(path)
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
