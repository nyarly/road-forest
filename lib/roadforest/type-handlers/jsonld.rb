require 'json/ld'
require 'roadforest/type-handlers/rdf-handler'
module RoadForest
  module TypeHandlers
    #application/ld+json
    class JSONLD < RDFHandler
      include Graph::Normalization

      def local_to_network(base_uri, rdf)
        raise "Invalid base uri: #{base_uri}" if base_uri.nil?
        prefixes = relevant_prefixes_for_graph(rdf)
        prefixes.keys.each do |prefix|
          prefixes[prefix.to_sym] = prefixes[prefix]
        end
        puts "\n#{__FILE__}:#{__LINE__} => \n#{rdf.dump(:ntriples)}"
        JSON::LD::Writer.buffer(:base_uri => base_uri.to_s,
                                :prefixes => prefixes) do |writer|
          rdf.each_statement do |statement|
            writer << statement
          end
                                end
      end

      def network_to_local(base_uri, source)
        raise "Invalid base uri: #{base_uri.inspect}" if base_uri.nil?
        graph = ::RDF::Graph.new
        reader = JSON::LD::Reader.new(source.to_s, :base_uri => base_uri.to_s)
        reader.each_statement do |statement|
          graph.insert(statement)
        end
        graph
      end
    end
  end
end
