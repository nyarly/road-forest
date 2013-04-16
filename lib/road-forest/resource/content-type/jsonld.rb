module RoadForest
  #Also: "blob" resource
  #Not yourself - simple file service
  #  allowed_methods - GET, HEAD
  #  post_is_create: default
  #  process_post: default
  #  content_types_accepted: defaults
  #Yourself - file transfer endpoint
  #  allowed_methods - GET, HEAD, POST, PUT, DELETE
  #  post_is_create: true
  #  process_post: default (unused)
  #  content_types_accepted: @model.update(params, blob) - update vs. create?

  #Other concerns:
  #Content type handling (iow: RDF<->text format)
  #Authentication
  #Authorization
  #Content encoding (gzip, compress)
  #Charsets
  #Languages
  #Exception handling
  #
  #HTML related:
  #  Method coercion (POST that means DELETE/PUT)
  #  Params -> graph
  #  Form rendering
  #
  #Cacheing - last_modified, expires, etag(+ W/)
  #
  #
  #Blending concern-focused modules
  #e.g. content_types_accepted - quality metrics, accept variants...
  #variance, conflict, options are related to the above (i.e. blended concerns)

  module Resource
    module ContentType
      def self.types_provided(modules)
        modules.map do |mod|
          mod.content_types.map do |type|
            [type, mod.to_source_method]
          end
        end.flatten
      end

      def self.types_accepted(modules)
        modules.map do |mod|
          mod.content_types.map do |type|
            [type, mod.from_source_method]
          end
        end.flatten
      end

      module JSONLD
        def self.content_types
          ["application/ld+json"]
        end

        def self.to_source_handler
          :to_jsonld
        end

        def self.from_source_handler
          :from_jsonld
        end

        def self.from_graph(rdf)
          JSON::LD::fromRDF(rdf)
        end

        def self.to_graph(source)
          graph = JSON::LD::API.toRDF(source)
        end

        def to_jsonld
          JSON::from_graph(@model.retreive(params))
        end

        def from_jsonld
          #PUT or POST as Create
          #Conflict? -> "resource.is_conflict?"
          #Location header
          #response body
          graph = JSONLD.to_graph(@request.body)
          result = update_model

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
