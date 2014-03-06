require 'cgi'
require 'roadforest/debug'
require 'rdf/rdfa'

module RoadForest::TypeHandlers
  ##
  # An RDFa 1.1 serialiser in Ruby. The RDFa serializer makes use of Haml templates, allowing runtime-replacement with alternate templates. Note, however, that templates should be checked against the W3C test suite to ensure that valid RDFa is emitted.
  #
  # Note that the natural interface is to write a whole graph at a time. Writing statements or Triples will create a graph to add them to and then serialize the graph.
  #
  # The writer will add prefix definitions, and use them for creating @prefix definitions, and minting CURIEs
  #
  # @example Obtaining a RDFa writer class
  #     RDF::Writer.for(:html)          => RDF::RDFa::Writer
  #     RDF::Writer.for("etc/test.html")
  #     RDF::Writer.for(:file_name      => "etc/test.html")
  #     RDF::Writer.for(:file_extension => "html")
  #     RDF::Writer.for(:content_type   => "application/xhtml+xml")
  #     RDF::Writer.for(:content_type   => "text/html")
  #
  # @example Serializing RDF graph into an XHTML+RDFa file
  #     RDF::RDFa::Write.open("etc/test.html") do |writer|
  #       writer << graph
  #     end
  #
  # @example Serializing RDF statements into an XHTML+RDFa file
  #     RDF::RDFa::Writer.open("etc/test.html") do |writer|
  #       graph.each_statement do |statement|
  #         writer << statement
  #       end
  #     end
  #
  # @example Serializing RDF statements into an XHTML+RDFa string
  #     RDF::RDFa::Writer.buffer do |writer|
  #       graph.each_statement do |statement|
  #         writer << statement
  #       end
  #     end
  #
  # @example Creating @base and @prefix definitions in output
  #     RDF::RDFa::Writer.buffer(:base_uri => "http://example.com/", :prefixes => {
  #         :foaf => "http://xmlns.com/foaf/0.1/"}
  #     ) do |writer|
  #       graph.each_statement do |statement|
  #         writer << statement
  #       end
  #     end
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  class RDFaWriter < RDF::Writer
    HAML_OPTIONS = {
      :ugly => true, # to preserve whitespace without using entities
    }

    # @return [Graph] Graph of statements serialized
    attr_accessor :graph

    # @return [RDF::URI] Base URI used for relativizing URIs
    attr_accessor :base_uri

    ##
    # Initializes the RDFa writer instance.
    #
    # @param  [IO, File] output
    #   the output stream
    # @param  [Hash{Symbol => Object}] options
    #   any additional options
    # @option options [Boolean]  :canonicalize (false)
    #   whether to canonicalize literals when serializing
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when constructing relative URIs, set as html>head>base.href
    # @option options [Boolean]  :validate (false)
    #   whether to validate terms when serializing
    # @option options [#to_s]   :lang   (nil)
    #   Output as root @lang attribute, and avoid generation _@lang_ where possible
    # @option options [Boolean]  :standard_prefixes   (false)
    #   Add standard prefixes to _prefixes_, if necessary.
    # @option options [Array<RDF::URI>] :top_classes ([RDF::RDFS.Class])
    #   Defines rdf:type of subjects to be emitted at the beginning of the document.
    # @option options [Array<RDF::URI>] :predicate_order ([RDF.type, RDF::RDFS.label, RDF::DC.title])
    #   Defines order of predicates to to emit at begninning of a resource description..
    # @option options [Array<RDF::URI>] :heading_predicates ([RDF::RDFS.label, RDF::DC.title])
    #   Defines order of predicates to use in heading.
    # @option options [String, Symbol, Hash{Symbol => String}] :haml (DEFAULT_HAML) HAML templates used for generating code
    # @option options [Hash] :haml_options (HAML_OPTIONS)
    #   Options to pass to Haml::Engine.new. Default options set `:ugly => false` to ensure that whitespace in literals with newlines is properly preserved.
    # @yield  [writer]
    # @yieldparam [RDF::Writer] writer
    def initialize(output = $stdout, options = {}, &block)
      super do
        @graph = RDF::Graph.new
        @valise = nil

        block.call(self) if block_given?
      end
    end

    ##
    # Write whole graph
    #
    # @param  [Graph] graph
    # @return [void]
    def write_graph(graph)
      @graph = graph
    end

    ##
    # Addes a statement to be serialized
    # @param  [RDF::Statement] statement
    # @return [void]
    # @raise [RDF::WriterError] if validating and attempting to write an invalid {RDF::Term}.
    def write_statement(statement)
      raise RDF::WriterError, "Statement #{statement.inspect} is invalid" if validate? && statement.invalid?
      @graph.insert(statement)
    end

    ##
    # Addes a triple to be serialized
    # @param  [RDF::Resource] subject
    # @param  [RDF::URI]      predicate
    # @param  [RDF::Value]    object
    # @return [void]
    # @raise  [NotImplementedError] unless implemented in subclass
    # @abstract
    # @raise [RDF::WriterError] if validating and attempting to write an invalid {RDF::Term}.
    def write_triple(subject, predicate, object)
      write_statement Statement.new(subject, predicate, object)
    end

    ##
    # Outputs the XHTML+RDFa representation of all stored triples.
    #
    # @return [void]
    def write_epilogue
      require 'roadforest/type-handlers/rdfa-writer/render-engine'
      @base_uri = RDF::URI(@options[:base_uri]) if @options[:base_uri]
      @lang = @options[:lang]
      @debug = @options[:debug]
      engine = RenderEngine.new(@graph, @debug) do |engine|
        engine.valise = Valise.define do
          ro up_to("lib") + "roadforest"
        end
        engine.style_name = @options[:haml]
        engine.base_uri = base_uri
        engine.lang = @lang
        engine.standard_prefixes = @options[:standard_prefixes]
        engine.top_classes = @options[:top_classes] || [RDF::RDFS.Class]
        engine.predicate_order = @options[:predicate_order] || [RDF.type, RDF::RDFS.label, RDF::DC.title]
        engine.heading_predicates = @options[:heading_predicates] || [RDF::RDFS.label, RDF::DC.title]
        engine.haml_options = @options[:haml_options]
      end

      engine.prefixes.merge! @options[:prefixes] unless @options[:prefixes].nil?

      # Generate document
      rendered = engine.render_document

      @output.write(rendered)
    end
  end
end
