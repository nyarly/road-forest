require 'cgi'
require 'roadforest/debug'
require 'rdf/rdfa'

module RoadForest::MediaType
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
      :ugly => false, # to preserve whitespace without using entities
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
      @base_uri = RDF::URI(@options[:base_uri]) if @options[:base_uri]
      @lang = @options[:lang]
      @debug = @options[:debug]
      engine = RenderEngine.new(@graph, @debug) do |engine|
        engine.valise = Valise.define do
          ro up_to("lib") + "roadforest"
        end
        engine.style_name = options[:haml]
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

    class RenderEngine
      # Defines rdf:type of subjects to be emitted at the beginning of the
      # document.
      # @return [Array<URI>]
      attr_accessor :top_classes

      # Defines order of predicates to to emit at begninning of a resource description. Defaults to `[rdf:type, rdfs:label, dc:title]`
      # @return [Array<URI>]
      attr_accessor :predicate_order

      # Defines order of predicates to use in heading.
      # @return [Array<URI>]
      attr_accessor :heading_predicates

      attr_accessor :prefixes, :base_uri, :lang, :standard_prefixes, :graph, :titles, :doc_title
      attr_accessor :valise, :resource_name, :style_name, :template_cache, :haml_options
      attr_reader :debug

      def initialize(graph, debug=nil)
        @debug = debug
        @graph = graph

        reset

        yield self

        setup
      end

      # Reset parser to run again
      def reset
        @debug_indent = 0
        @uri_to_term_or_curie = {}
        @uri_to_prefix = {}
        @references = Hash.new{|h,k| h[k] = 0}
        @prefixes = {}
        @serialized = {}
        @subjects = {}
        @ordered_subjects = []
        @titles = {}
        @doc_title = ""
      end

      def template_cache
        @template_cache ||= ::Tilt::Cache.new
      end

      def style_name
        @style_name ||= "base"
      end

      def setup_env(env)
        env.heading_predicates = heading_predicates
        env.lang = lang
      end

      # Increase depth around a method invocation
      # @yield
      #   Yields with no arguments
      # @yieldreturn [Object] returns the result of yielding
      # @return [Object]
      def depth
        @debug_indent += 1
        ret = yield
        @debug_indent -= 1
        ret
      end

      ##
      # Find a template appropriate for the subject.
      # Override this method to provide templates based on attributes of a given subject
      #
      # @param [RDF::URI] subject
      # @return [Hash] # return matched matched template
      def find_template(kind)
        templates.find(kind).contents
      end

      def templates
        @templates ||= [resource_name, style_name, nil].uniq.map do |name|
          valise.sub_set(["templates", name].compact.join("/"))
        end.inject do |left, right|
          left + right
        end.templates("") do |type|
          template_config(type)
        end
      end

      def template_config(type)
        config = { :template_cache => template_cache }
        case type
        when "haml"
          config[:template_options] = haml_options
        end
        config
      end

      # Increase the reference count of this resource
      # @param [RDF::Resource] resource
      # @return [Integer] resulting reference count
      def bump_reference(resource)
        @references[resource] += 1
      end

      # Return the number of times this node has been referenced in the object position
      # @param [RDF::Node] node
      # @return [Boolean]
      def ref_count(node)
        @references[node]
      end

      # Add debug event to debug array, if specified
      #
      # @param [String] message
      # @yieldreturn [String] appended to message, to allow for lazy-evaulation of message
      def add_debug(message = nil)
        return unless ::RoadForest.debug_io || @debug
        message ||= ""
        message = message + yield if block_given?
        msg = "#{'  ' * @debug_indent}#{message}"
        RoadForest::debug(msg)
        @debug << msg.force_encoding("utf-8") if @debug.is_a?(Array)
      end

      def setup
        add_debug {"\nserialize setup: graph size: #{@graph.size}"}

        preprocess

        @ordered_subjects = order_subjects

        # Take title from first subject having a heading predicate
        @doc_title = nil
        heading_predicates.each do |pred|
          @graph.query(:predicate => pred) do |statement|
            titles[statement.subject] ||= statement.object
          end
        end
        title_subject = @ordered_subjects.detect {|subject| titles[subject]}
        @doc_title = titles[title_subject]
      end

      # Perform any preprocessing of statements required
      # @return [ignored]
      def preprocess
        # Load initial contexts
        # Add terms and prefixes to local store for converting URIs
        # Keep track of vocabulary from left-most context
        [RDF::RDFa::XML_RDFA_CONTEXT, RDF::RDFa::HTML_RDFA_CONTEXT].each do |uri|
          ctx = RDF::RDFa::Context.find(uri)
          ctx.prefixes.each_pair do |k, v|
            @uri_to_prefix[v] = k unless k.to_s == "dcterms"
          end

          ctx.terms.each_pair do |k, v|
            @uri_to_term_or_curie[v] = k
          end

          @vocabulary = ctx.vocabulary.to_s if ctx.vocabulary
        end

        # Load defined prefixes
        (@prefixes || {}).each_pair do |k, v|
          @uri_to_prefix[v.to_s] = k
        end
        @prefixes = {}  # Will define actual used when matched

        # Process each statement to establish CURIEs and Terms
        @graph.each {|statement| preprocess_statement(statement)}
        add_debug{ "preprocess prefixes: #{@prefixes.inspect}" }
      end

      # Order subjects for output. Override this to output subjects in another order.
      #
      # Uses #top_classes and #base_uri.
      # @return [Array<Resource>] Ordered list of subjects
      def order_subjects
        seen = {}
        subjects = []

        # Start with base_uri
        if base_uri && @subjects.keys.include?(base_uri)
          subjects << base_uri
          seen[base_uri] = true
        end

        # Add distinguished classes
        top_classes.select do |s|
          !seen.include?(s)
        end.each do |class_uri|
          graph.query(:predicate => RDF.type, :object => class_uri).map {|st| st.subject}.sort.uniq.each do |subject|
            #add_debug {"order_subjects: #{subject.inspect}"}
            subjects << subject
            seen[subject] = true
          end
        end

        # Sort subjects by resources over nodes, ref_counts and the subject URI itself
        recursable = @subjects.keys.select do |s|
          !seen.include?(s)
        end.map do |r|
          [r.is_a?(RDF::Node) ? 1 : 0, ref_count(r), r]
        end.sort

        add_debug {"order_subjects: #{recursable.inspect}"}

        subjects += recursable.map{|r| r.last}
      end

      # Take a hash from predicate uris to lists of values.
      # Sort the lists of values.  Return a sorted list of properties.
      #
      # @param [Hash{String => Array<Resource>}] properties A hash of Property to Resource mappings
      # @return [Array<String>}] Ordered list of properties. Uses predicate_order.
      def order_properties(properties)
        # Make sorted list of properties
        prop_list = []

        predicate_order.each do |prop|
          next unless properties[prop.to_s]
          prop_list << prop.to_s
        end

        properties.keys.sort.each do |prop|
          next if prop_list.include?(prop.to_s)
          prop_list << prop.to_s
        end

        add_debug {"order_properties: #{prop_list.join(', ')}"}
        prop_list
      end

      # Perform any statement preprocessing required. This is used to perform reference counts and determine required prefixes.
      # @param [RDF::Statement] statement
      # @return [ignored]
      def preprocess_statement(statement)
        #add_debug {"preprocess: #{statement.inspect}"}
        bump_reference(statement.subject)
        bump_reference(statement.object)
        @subjects[statement.subject] = true
        get_curie(statement.subject)
        get_curie(statement.predicate)
        get_curie(statement.object)
        get_curie(statement.object.datatype) if statement.object.literal? && statement.object.has_datatype?
      end

      def get_curie(resource)
        raise RDF::WriterError, "Getting CURIE for #{resource.inspect}, which must be an RDF value" unless resource.is_a?(RDF::Value)
        return resource.to_s unless resource.uri?

        uri = resource.to_s

        curie =
          case
          when @uri_to_term_or_curie.has_key?(uri)
            add_debug {"get_curie(#{uri}): uri_to_term_or_curie #{@uri_to_term_or_curie[uri].inspect}"}
            return @uri_to_term_or_curie[uri]
          when base_uri && uri.index(base_uri.to_s) == 0
            add_debug {"get_curie(#{uri}): base_uri (#{uri.sub(base_uri.to_s, "")})"}
            uri.sub(base_uri.to_s, "")
          when @vocabulary && uri.index(@vocabulary) == 0
            add_debug {"get_curie(#{uri}): vocabulary"}
            uri.sub(@vocabulary, "")
          when u = @uri_to_prefix.keys.detect {|u| uri.index(u.to_s) == 0}
            add_debug {"get_curie(#{uri}): uri_to_prefix"}
            prefix = @uri_to_prefix[u]
            @prefixes[prefix] = u
            uri.sub(u.to_s, "#{prefix}:")
          when @standard_prefixes && vocab = RDF::Vocabulary.detect {|v| uri.index(v.to_uri.to_s) == 0}
            add_debug {"get_curie(#{uri}): standard_prefixes"}
            prefix = vocab.__name__.to_s.split('::').last.downcase
            @prefixes[prefix] = vocab.to_uri
            uri.sub(vocab.to_uri.to_s, "#{prefix}:")
          else
            add_debug {"get_curie(#{uri}): none"}
            uri
          end

        add_debug {"get_curie(#{resource}) => #{curie}"}

        @uri_to_term_or_curie[uri] = curie
      rescue ArgumentError => e
        raise RDF::WriterError, "Invalid URI #{uri.inspect}: #{e.message}"
      end

      def render(template, context)
        add_debug "render"
        depth do
          add_debug{ "template: #{template.file}" }
          add_debug{ "context: #{context.inspect}"}
        end
        template.render(context) do |item|
          context.yielded(item)
        end
      end

      # Mark a subject as done.
      # @param [RDF::Resource] subject
      # @return [Boolean]
      def subject_done(subject)
        @serialized[subject] = true
      end

      # Determine if the subject has been completed
      # @param [RDF::Resource] subject
      # @return [Boolean]
      def is_done?(subject)
        @serialized.include?(subject)
      end

      # Render a single- or multi-valued predicate using
      # `haml_template[:property_value]` or `haml_template[:property_values]`.
      # Yields each object for optional rendering. The block should only render
      # for recursive subject definitions (i.e., where the object is also a
      # subject and is rendered underneath the first referencing subject).
      #
      # If a multi-valued property definition is not found within the template, the writer will use the single-valued property definition multiple times.
      #
      # @param [Array<RDF::Resource>] predicate
      #   Predicate to render.
      # @param [Array<RDF::Resource>] objects
      #   List of objects to render. If the list contains only a single element, the :property_value template will be used. Otherwise, the :property_values template is used.
      # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
      # @option options [String] :haml (haml_template[:property_value], haml_template[:property_values])
      #   Haml template to render. Otherwise, uses `haml_template[:property_value] or haml_template[:property_values]`
      #   depending on the cardinality of objects.
      # @yield object, inlist
      #   Yields object and if it is contained in a list.
      # @yieldparam [RDF::Resource] object
      # @yieldparam [Boolean] inlist
      # @yieldreturn [String, nil]
      #   The block should only return a string for recursive object definitions.
      # @return String
      #   The rendered document is returned as a string
      #
      #
      def render_predicate(subject, pred)
        pred = RDF::URI(pred) if pred.is_a?(String)
        objects = properties_for_subject(subject)[pred.to_s]

        add_debug {"predicate: #{pred.inspect}, objects: #{objects}"}

        return if objects.to_a.empty?

        nonlists, lists = objects.partition do |object|
          object == RDF.nil || (l = RDF::List.new(object, @graph)).invalid?
        end

        add_debug {"properties with lists: #{lists} non-lists: #{nonlists}"}
        return render_simple_property(pred, nonlists) + render_list_property(pred, lists)
      end

      #Objects array guaranteed not to include lists
      def render_simple_property(predicate, objects, &block)
        return "" if objects.to_a.empty?

        template = nil
        if objects.to_a.length > 1
          template = find_template("property_values")
          if template.nil?
            return objects.map do |object|
              depth do
                render_simple_property(predicate, [object], &block)
              end
            end.join(" ")
          end
        else
          template = find_template("property_value")
        end

        raise RDF::WriterError, "Missing property template" if template.nil?

        env = PropertyEnvironment.new(self)
        setup_env(env)
        env.objects = objects
        env.object = objects.first
        env.predicate = predicate
        env.property = get_curie(predicate)
        env.rel = get_curie(predicate)
        env.inlist = nil

        yield env if block_given?

        render(template, env)
      end

      def render_list_property(predicate, list_objects, &block)
        return "" if list_objects.to_a.empty?

        return list_objects.map do |object|
          # Render each list as multiple properties and set :inlist to true
          list = RDF::List.new(object, @graph)
          list.each_statement {|st| subject_done(st.subject)}

          add_debug {"list: #{list.inspect} #{list.to_a}"}
          depth do
            render_simple_property(predicate, list.to_a) do |env|
              env.inlist = "true"
            end
          end
        end.join(" ")
      end

      # @param [RDF::Resource] subject
      # @return [Hash{String => Object}]
      def properties_for_subject(subject)
        properties = {}
        @graph.query(:subject => subject) do |st|
          key = st.predicate.to_s.freeze
          properties[key] ||= []
          properties[key] << st.object
        end
        properties
      end

      # @param [Array,NilClass] type
      # @param [RDF::Resource] subject
      # @return [String] string representation of the specific RDF.type uri
      def type_of(type, subject)
        # Find appropriate template
        curie = case
                when subject.node?
                  subject.to_s if ref_count(subject) > 1
                else
                  get_curie(subject)
                end

        typeof = Array(type).map {|r| get_curie(r)}.join(" ")
        typeof = nil if typeof.empty?

        # Nodes without a curie need a blank @typeof to generate a subject
        typeof ||= "" unless curie

        add_debug {"subject: #{curie.inspect}, typeof: #{typeof.inspect}" }

        typeof.freeze
      end

      # @param [RDF::Resource] subject
      # @param [Array] prop_list
      # @param [Hash] render_opts
      # @return [String]
      def render_subject(subject, render_opts)
        # See if there's a template based on the sorted concatenation of all types of this subject
        # or any type of this subject
        return unless @subjects.include?(subject)
        return if is_done?(subject)

        subject_done(subject)

        properties = properties_for_subject(subject)
        typeof = type_of(properties.delete(RDF.type.to_s), subject)
        prop_list = order_properties(properties)

        add_debug {"props: #{prop_list.inspect}"}

        template = find_template("subject")
        add_debug {"subject: found template #{template.file.inspect}"}

        # Render this subject
        # If :rel is specified and :typeof is nil, use @resource instead of @about.
        # Pass other options from calling context

        env = SubjectEnvironment.new(self)
        env.base = base_uri
        env.predicates = prop_list
        env.subject = subject
        env.typeof = typeof

        yield env if block_given?

        depth do
          render(template, env)
        end
      end

      # Render document using `haml_template[:doc]`. Yields each subject to be
      # rendered separately.
      #
      # @param [Array<RDF::Resource>] subjects
      #   Ordered list of subjects. Template must yield to each subject, which returns
      #   the serialization of that subject (@see #subject_template)
      # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
      # @option options [RDF::URI] base (nil)
      #   Base URI added to document, used for shortening URIs within the document.
      # @option options [Symbol, String] language (nil)
      #   Value of @lang attribute in document, also allows included literals to omit
      #   an @lang attribute if it is equivalent to that of the document.
      # @option options [String] title (nil)
      #   Value of html>head>title element.
      # @option options [String] prefix (nil)
      #   Value of @prefix attribute.
      # @option options [String] haml (haml_template[:doc])
      #   Haml template to render.
      # @yield [subject]
      #   Yields each subject
      # @yieldparam [RDF::URI] subject
      # @yieldreturn [:ignored]
      # @return String
      #   The rendered document is returned as a string
      def render_document
        add_debug{ "engine prefixes: #{prefixes.inspect}"}
        env = DocumentEnvironment.new(self)
        env.subjects = @ordered_subjects
        env.title = doc_title
        env.prefixes = prefixes
        env.lang = lang
        env.base = base_uri

        yield env if block_given?

        render(find_template("doc"), env)
      end

      # Render a subject using `haml_template[:subject]`.
      #
      # The _subject_ template may be called either as a top-level element, or recursively under another element if the _rel_ local is not nil.
      #
      # Yields each predicate/property to be rendered separately (@see #render_property_value and `#render_property_values`).
      #
      # @param [Array<RDF::Resource>] subject
      #   Subject to render
      # @param [Array<RDF::Resource>] predicates
      #   Predicates of subject. Each property is yielded for separate rendering.
      # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
      # @option options [String] about (nil)
      #   About description, a CURIE, URI or Node definition.
      #   May be nil if no @about is rendered (e.g. unreferenced Nodes)
      # @option options [String] resource (nil)
      #   Resource description, a CURIE, URI or Node definition.
      #   May be nil if no @resource is rendered
      # @option options [String] rel (nil)
      #   Optional @rel property description, a CURIE, URI or Node definition.
      # @option options [String] typeof (nil)
      #   RDF type as a CURIE, URI or Node definition.
      #   If :about is nil, this defaults to the empty string ("").
      # @option options [:li, nil] element (nil)
      #   Render with &lt;li&gt;, otherwise with template default.
      # @option options [String] haml (haml_template[:subject])
      #   Haml template to render.
      # @yield [predicate]
      #   Yields each predicate
      # @yieldparam [RDF::URI] predicate
      # @yieldreturn [:ignored]
      # @return String
      #   The rendered document is returned as a string
      # Return Haml template for document from `haml_template[:subject]`
    end

    class RenderEnvironment
      attr_accessor :heading_predicates, :lang

      def initialize(engine)
        @_engine = engine
      end

      def add_debug(msg = nil, &block)
        @_engine.add_debug(msg, &block)
      end

      def inspect
        "<#{self.class.name}:#{"%x" % self.object_id} #{instance_variables.map do |name|
          next if name == :@_engine
          "#{name}=#{instance_variable_get(name).inspect}"
        end.compact.join(" ")}>"
      end
      # Display a subject.
      #
      # If the Haml template contains an entry matching the subject's rdf:type URI, that entry will be used as the template for this subject and it's properties.
      #
      # @example Displays a subject as a Resource Definition:
      #     <div typeof="rdfs:Resource" about="http://example.com/resource">
      #       <h1 property="dc:title">label</h1>
      #       <ul>
      #         <li content="2009-04-30T06:15:51Z" property="dc:created">2009-04-30T06:15:51+00:00</li>
      #       </ul>
      #     </div>
      #
      # @param [RDF::Resource] subject
      # @param [Hash{Symbol => Object}] options
      # @option options [:li, nil] :element(:div)
      #   Serialize using &lt;li&gt; rather than template default element
      # @option options [RDF::Resource] :rel (nil)
      #   Optional @rel property
      # @return [String]
      def subject(subject, options = {}, &block)
        @_engine.render_subject(subject, options, &block)
      end

      # Haml rendering helper. Return CURIE for the literal datatype, if the
      # literal is a typed literal.
      #
      # @param [RDF::Resource] literal
      # @return [String, nil]
      # @raise [RDF::WriterError]
      def get_dt_curie(literal)
        raise RDF::WriterError, "Getting datatype CURIE for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
        get_curie(literal.datatype) if literal.literal? && literal.datatype?
      end

      # Haml rendering helper. Return language for plain literal, if there is no language, or it is the same as the document, return nil
      #
      # @param [RDF::Literal] literal
      # @return [Symbol, nil]
      # @raise [RDF::WriterError]
      def get_lang(literal)
        raise RDF::WriterError, "Getting datatype CURIE for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
        literal.language if literal.literal? && literal.language && literal.language.to_s != @lang.to_s
      end

      # Haml rendering helper. Data to be added to a @content value
      #
      # @param [RDF::Literal] literal
      # @return [String, nil]
      # @raise [RDF::WriterError]
      def get_content(literal)
        raise RDF::WriterError, "Getting content for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
        case literal
        when RDF::Literal::Date, RDF::Literal::Time, RDF::Literal::DateTime
          literal.to_s
        end
      end

      # Haml rendering helper. Display value for object, may be non-canonical if get_content returns a non-nil value
      #
      # @param [RDF::Literal] literal
      # @return [String]
      # @raise [RDF::WriterError]
      def get_value(literal)
        raise RDF::WriterError, "Getting value for #{literal.inspect}, which must be a literal" unless literal.is_a?(RDF::Literal)
        case literal
        when RDF::Literal::Date
          literal.object.strftime("%A, %d %B %Y")
        when RDF::Literal::Time
          literal.object.strftime("%H:%M:%S %Z").sub(/\+00:00/, "UTC")
        when RDF::Literal::DateTime
          literal.object.strftime("%H:%M:%S %Z on %A, %d %B %Y").sub(/\+00:00/, "UTC")
        else
          literal.to_s
        end
      rescue
        literal.to_s  # When all else fails ...
      end

      # Haml rendering helper. Return an appropriate label for a resource.
      #
      # @param [RDF::Resource] resource
      # @return [String]
      # @raise [RDF::WriterError]
      def get_predicate_name(resource)
        raise RDF::WriterError, "Getting predicate name for #{resource.inspect}, which must be a resource" unless resource.is_a?(RDF::Resource)
        get_curie(resource)
      end

      # rendering helper. Return appropriate, term, CURIE or URI for the given
      # resource.
      #
      # @param [RDF::Value] resource
      # @return [String] value to use to identify URI
      # @raise [RDF::WriterError]
      def get_curie(resource)
        @_engine.get_curie(resource)
      end

      ##
      # Haml rendering helper. Escape entities to avoid whitespace issues.
      #
      # # In addtion to "&<>, encode \n and \r to ensure that whitespace is properly preserved
      #
      # @param [String] str
      # @return [String]
      #   Entity-encoded string
      def escape_entities(str)
        CGI.escapeHTML(str).gsub(/[\n\r]/) {|c| '&#x' + c.unpack('h').first + ';'}
      end
    end

    class DocumentEnvironment < RenderEnvironment
      attr_accessor :subjects, :title, :prefixes, :lang, :base
      def yielded(item)
        subject(item)
      end

      def prefix
        @prefix ||=
          if prefixes.empty?
            nil
          else
            prefixes.keys.map {|pk| "#{pk}: #{prefixes[pk]}"}.sort.join(" ")
          end.tap{|prefix| add_debug {"\nserialize: prefixes: #{prefixes.inspect} prefix src: #{prefix.inspect}"}}
      end
    end

    class SubjectEnvironment < RenderEnvironment
      attr_accessor :about, :base, :element, :predicates, :rel, :inlist, :resource, :subject, :typeof

      # Write a predicate with one or more values.
      #
      # Values may be a combination of Literal and Resource (Node or URI).
      # @param [RDF::Resource] predicate
      #   Predicate to serialize
      # @param [Array<RDF::Resource>] objects
      #   Objects to serialize
      # @return [String]
      def predicate(predicate)
        @_engine.render_predicate(subject, predicate)
      end

      def about
        if rel.nil?
          get_curie(subject)
        else
          nil
        end
      end

      def resource
        if rel.nil?
          nil
        else
          get_curie(subject)
        end
      end

      def yielded(pred)
        predicate(pred)
      end
    end

    class PropertyEnvironment < RenderEnvironment
      attr_accessor :objects, :object, :predicate, :property, :rel, :inlist
      def yielded(item)
        subject(item) do |env|
          env.rel = get_curie(predicate)
          env.inlist = inlist
          env.element = :li if objects.length > 1 || inlist
        end
      end
    end

  end
end
