require 'json/ld'

module RoadForest
  module Resource
    module ContentType
      def self.types_provided(modules)
        modules.inject([]) do |array, mod|
          array + mod.content_types.map do |type|
            [type, mod.to_source_method]
          end
        end
      end

      def self.types_accepted(modules)
        modules.inject([]) do |array, mod|
          array + mod.content_types.map do |type|
            [type, mod.from_source_method]
          end
        end
      end

      module JSONLD
        def self.content_types
          ["application/ld+json"]
        end

        def self.to_source_method
          :to_jsonld
        end

        def self.from_source_method
          :from_jsonld
        end

        def self.from_graph(rdf)
          JSON::LD::Writer.buffer do |writer|
            rdf.each_statement(:local) do |statement|
              writer << statement
            end
          end
        end

        def self.to_graph(source)
          reader = JSON::LD::Reader.new(source)
          reader.graph
        end

        def to_jsonld
          result = retreive_model
          JSONLD::from_graph(result.graph)
        end

        def from_jsonld
          #PUT or POST as Create
          #Conflict? -> "resource.is_conflict?"
          #Location header
          #response body
          graph = JSONLD.to_graph(@request.body)
          result = update_model(graph)

          if result.go_to_resource
            @response.location = result.go_to_resource
          end

          if result.graph
            JSONLD.from_graph(result.graph)
          end
        end
      end
    end
  end
end
