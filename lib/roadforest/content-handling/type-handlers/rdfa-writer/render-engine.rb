require 'roadforest/content-handling/type-handlers/rdfa-writer'
require 'roadforest/content-handling/type-handlers/rdfa-writer/document-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/subject-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/property-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/object-environment'
require 'haml'

module RoadForest::MediaType
  class RDFaWriter
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

      def templates
        @templates ||= [resource_name, style_name, nil].uniq.map do |name|
          valise.sub_set(["templates", name].compact.join("/"))
        end.inject do |left, right|
          left + right
        end.handle_templates do |config|
          config.add_type("haml", { :template_cache => template_cache, :template_options => haml_options })
        end
      end

      ##
      # Find a template appropriate for the subject.
      # Override this method to provide templates based on attributes of a given subject
      #
      # @param [RDF::URI] subject
      # @return [Hash] # return matched matched template
      def find_template(kinds)
        kind = kinds.shift
        templates.contents(kind)
      rescue Valise::Errors::NotFound
        if kinds.empty?
          raise RDF::WriterError, "Missing template for #{context.class.name}" if template.nil?
        else
          retry
        end
      end

      def find_environment_template(env)
        find_template(env.template_kinds)
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

        @base_uri = ::RDF::URI.intern(@base_uri) unless @base_uri.nil? or @base_uri.is_a?(::RDF::URI)

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
        raise RDF::WriterError, "Getting CURIE for #{resource.inspect}, which must be an RDF value" unless resource.is_a? RDF::Value
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

      def render(context)
        add_debug "render"
        if context.render_checked
          return ""
        end
        template = find_environment_template(context)
        depth do
          add_debug{ "template: #{template.file}" }
          add_debug{ "context: #{context.inspect}"}

          template.render(context) do |item|
            context.yielded(item)
          end.sub(/\n\Z/,'')
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

      def list_property_envs(predicate, list_objects)
        return list_objects.map do |object|
          # Render each list as multiple properties and set :inlist to true
          list = RDF::List.new(object, @graph)
          list.each_statement {|st| subject_done(st.subject)}

          add_debug {"list: #{list.inspect} #{list.to_a}"}
          env = simple_property_env(predicate, list.to_a)
          env.inlist = "true"
          env
        end
      end

      def object_env(predicate, object)
        subj = subject_env(object)
        unless subj.nil?
          subj.rel = get_curie(predicate)
          return subj
        end

        env =
          if get_curie(object) == 'rdf:nil'
            NilObjectEnvironment.new(self)
          elsif object.node?
            NodeObjectEnvironment.new(self)
          elsif object.uri?
            UriObjectEnvironment.new(self)
          elsif object.datatype == RDF.XMLLiteral
            XMLLiteralObjectEnvironment.new(self)
          else
            ObjectEnvironment.new(self)
          end
        env.predicate = predicate
        env.object = object
        env.inlist = nil

        env
      end

      def simple_property_env(predicate, objects)
        return nil if objects.to_a.empty?

        env = PropertyEnvironment.new(self)
        setup_env(env)
        env.object_terms = objects
        env.predicate = predicate
        env.inlist = nil

        env
      end

      def subject_env(subject)
        return unless @subjects.include?(subject)
        properties = properties_for_subject(subject)

        env = SubjectEnvironment.new(self)
        env.base = base_uri
        env.predicate_terms = order_properties(properties)
        env.property_objects = properties
        env.subject = subject
        env.typeof = type_of(properties.delete(RDF.type.to_s), subject)

        env
      end

      def document_env
        env = DocumentEnvironment.new(self)
        env.subject_terms = @ordered_subjects
        env.title = doc_title
        env.prefixes = prefixes
        env.lang = lang
        env.base = base_uri
        env
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

        return ([simple_property_env(pred, nonlists)] + list_property_envs(pred, lists)).compact.map do |env|
          render(env)
        end.join(" ")
      end

      def is_list?(object)
        !(object == RDF.nil || (l = RDF::List.new(object, @graph)).invalid?)
      end

      # @param [RDF::Resource] subject
      # @param [Array] prop_list
      # @param [Hash] render_opts
      # @return [String]
      def render_subject(subject)
        # See if there's a template based on the sorted concatenation of all types of this subject
        # or any type of this subject

        env = subject_env(subject)

        return if env.nil?

        yield env if block_given?

        add_debug {"props: #{env.predicates.inspect}"}

        render(env)
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
        env = document_env

        yield env if block_given?

        render(env)
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
  end
end
