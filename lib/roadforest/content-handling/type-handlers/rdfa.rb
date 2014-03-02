require 'rdf/rdfa' #XXX Otherwise json-ld grabs RDFa documents. Awaiting fix upstream
require 'rdf'
require 'roadforest/content-handling/type-handlers/rdf-handler'
require 'roadforest/content-handling/type-handlers/rdfa-writer/render-engine'
module RoadForest
  module MediaType
    module Handlers
      #text/html;q=1;rdfa
      #image/svg+xml;q=1;rdfa
      #application/xhtml+xml;q=1;rdfa
      #text/html
      #image/svg+xml
      #application/xhtml+xml
      class RDFa < RDFHandler
        include Graph::Normalization

        attr_writer :valise, :tilt_cache

        def valise
          @valise ||= Valise.define do
            ro up_to("lib") + "roadforest"
          end
        end

        def tilt_cache
          @tilt_cache ||= ::Tilt::Cache.new
        end

        def local_to_network(base_uri, rdf)
          raise "Invalid base uri: #{base_uri}" if base_uri.nil?

          debug = []

          templates = RDFaWriter::TemplateHandler.new
          templates.valise = valise
          templates.template_cache = tilt_cache

          engine = RDFaWriter::RenderEngine.new(rdf, debug) do |engine|
            engine.graph_name = rdf.context
            engine.base_uri = base_uri
            engine.standard_prefixes = true
            engine.template_handler = templates

            #engine.style_name = options[:haml]
            #engine.lang = options[:lang]

            engine.top_classes = [::RDF::RDFS.Class]
            engine.predicate_order = [::RDF.type, ::RDF::RDFS.label, ::RDF::DC.title]
            engine.heading_predicates = [::RDF::RDFS.label, ::RDF::DC.title]
          end

          prefixes = relevant_prefixes_for_graph(rdf)
          prefixes.keys.each do |prefix|
            prefixes[prefix.to_sym] = prefixes[prefix]
          end
          engine.prefixes.merge! prefixes

          #$stderr.puts debug

          result = engine.render_document
        end

        def network_to_local(base_uri, source)
          raise "Invalid base uri: #{base_uri.inspect}" if base_uri.nil?
          graph = ::RDF::Graph.new
          reader = ::RDF::RDFa::Reader.new(source.to_s, :base_uri => base_uri.to_s)
          reader.each_statement do |statement|
            graph.insert(statement)
          end
          graph
        end
      end
    end
  end
end
