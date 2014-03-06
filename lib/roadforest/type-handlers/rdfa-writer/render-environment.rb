require 'roadforest/type-handlers/rdfa-writer'
module RoadForest::TypeHandlers
  class RDFaWriter
    class RenderEnvironment
      attr_accessor :heading_predicates, :lang, :parent
      attr_reader :_engine

      def initialize(engine)
        @_engine = engine
      end

      def _base_env_
        self
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

      def like_a?(klass)
        is_a?(klass)
      end

      def is_subject?
        false
      end

      def literal?
        false
      end

      def render_checked
        false
      end

      def yielded(item)
        _engine.render(item)
      end

      def subject_env(term)
        _engine.subject_env(term)
      end

      def simple_property_env(predicate, nonlists)
        _engine.simple_property_env(predicate, nonlists)
      end

      def list_property_envs(predicate, lists)
        _engine.list_property_envs(predicate, lists)
      end

      def object_env(predicate, term)
        _engine.object_env(predicate, term)
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
        literal.language if literal.literal? && literal.language && literal.language.to_s != _engine.lang.to_s
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
        _engine.get_curie(resource)
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
  end
end
