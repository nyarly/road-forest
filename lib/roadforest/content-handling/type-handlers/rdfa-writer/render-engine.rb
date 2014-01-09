require 'roadforest/content-handling/type-handlers/rdfa-writer'
require 'roadforest/content-handling/type-handlers/rdfa-writer/document-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/subject-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/property-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/object-environment'
require 'roadforest/content-handling/type-handlers/rdfa-writer/environment-decorator'
require 'haml'

module RoadForest::MediaType
  class RDFaWriter
    class TemplateHandler
      attr_accessor :haml_options, :valise
      attr_accessor :resource_name
      attr_writer :style_name, :template_cache

      def template_cache
        @template_cache ||= ::Tilt::Cache.new
      end

      def style_name
        @style_name ||= "base"
      end

      def templates
        @templates ||= [resource_name, style_name, nil].uniq.map do |name|
          valise.sub_set(["templates", name].compact.join("/"))
        end.inject do |left, right|
          left + right
        end.handle_templates do |config|
          #At some point, should look into using HTML entities to preserve
          #whitespace in XMLLiterals
          config.add_type("haml", { :template_cache => template_cache, :template_options => haml_options || {:ugly => true} })
        end
      end

      def find_template(kinds)
        kind = kinds.shift
        templates.contents(kind)
      rescue Valise::Errors::NotFound
        if kinds.empty?
          raise
        else
          retry
        end
      end
    end


    class RenderEngine
      attr_accessor :top_classes

      attr_accessor :predicate_order

      attr_accessor :heading_predicates

      attr_accessor :prefixes, :base_uri, :lang, :standard_prefixes, :graph, :titles, :doc_title
      attr_accessor :template_handler
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

      def depth
        @debug_indent += 1
        ret = yield
        @debug_indent -= 1
        ret
      end

      def bump_reference(resource)
        @references[resource] += 1
      end

      def ref_count(node)
        @references[node]
      end

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

      def preprocess
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
        return unless statement.context.nil?
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

      def find_environment_template(env)
        template_handler.find_template(env.template_kinds)
      rescue Valise::Errors::NotFound
        raise RDF::WriterError, "No template found for #{env.class} in #{template_handler.inspect}"
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

      def is_list?(object)
        !(object == RDF.nil || (l = RDF::List.new(object, @graph)).invalid?)
      end

      def subject_done(subject)
        @serialized[subject] = true
      end

      def is_done?(subject)
        @serialized.include?(subject)
      end

      def properties_for_subject(subject)
        properties = {}
        @graph.query(:subject => subject, :context => false) do |st|
          key = st.predicate.to_s.freeze
          properties[key] ||= []
          properties[key] << st.object
        end
        properties
      end

      def setup_env(env)
        env.heading_predicates = heading_predicates
        env.lang = lang
      end

      def decorate_env(env)
        EnvironmentDecorator.decoration_for(env)
      end

      def document_env
        env = DocumentEnvironment.new(self)
        setup_env(env)
        env.subject_terms = @ordered_subjects
        env.title = doc_title
        env.prefixes = prefixes
        env.lang = lang
        env.base = base_uri
        env = decorate_env(env)
        env
      end

      def subject_env(subject)
        return unless @subjects.include?(subject)
        properties = properties_for_subject(subject)

        env = SubjectEnvironment.new(self)
        setup_env(env)
        env.base = base_uri
        env.predicate_terms = order_properties(properties)
        env.property_objects = properties
        env.subject = subject
        env.typeof = type_of(properties.delete(RDF.type.to_s), subject)

        env = decorate_env(env)
        env
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

      def simple_property_env(predicate, objects)
        return nil if objects.to_a.empty?

        env = PropertyEnvironment.new(self)
        setup_env(env)
        env.object_terms = objects
        env.predicate = predicate
        env.inlist = nil

        env = decorate_env(env)
        env
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
        setup_env(env)
        env.predicate = predicate
        env.object = object
        env.inlist = nil
        env = decorate_env(env)

        env
      end

      def render_document
        add_debug{ "engine prefixes: #{prefixes.inspect}"}
        env = document_env

        yield env if block_given?

        render(env)
      end
    end
  end
end
