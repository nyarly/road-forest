require 'rdf'

module RoadForest::RDF
  module Normalization
    Vocabs = {}
    Vocabs["rdf"] = RDF

    def normalize_statement(subject, predicate, object, context)
      subject = normalize_resource(subject) || RDF::Node.new
      predicate = normalize_uri(predicate)
      object = normalize_term(object) || RDF::Node.new
      context = normalize_resource(context)

      RDF::Statement.new(subject, predicate, object, :context => context)
    end

    def normalize_tuple(tuple)
      subject, predicate, object, context = *tuple
      [ normalize_resource(subject) || RDF::Node.new, normalize_uri(predicate), normalize_term(object) || RDF::Node.new, normalize_resource(context) ]
    end

    def normalize_resource(from)
      from = expand_curie(from)
      case from
      when nil
      when RDF::Resource
      when /^_:/
        from = RDF::Resource.new(from)
      when String, RDF::URI, Addressable::URI
        from = interned_uri(from)
      when Symbol
        from = RDF::Node.new(from)
      else
        from = RDF::Resource.new(from)
      end
      return from
    end

    def normalize_context(from)
      case from
      when Array
        from = expand_curie(from)
      when RDF::URI, Addressable::URI, String
        from = uri(from)
      else
        return nil
      end
      from.fragment = nil
      return RDF::URI.intern(from.to_s)
    end

    def normalize_uri(from)
      from = expand_curie(from)
      case from
      when nil
      when RDF::URI
      else
        from = interned_uri(from)
      end
      return from
    end

    def normalize_term(object)
      if Array === object
        RDF::Resource.new(expand_curie(object))
      else
        object
      end
    end

    def literal(object)
      RDF::Literal.new(object)
    end

    def expand_curie_pair(prefix, property)
      vocab = Vocabs.fetch(prefix) do
        vocab = RDF::Vocabulary.find do |vocab|
          vocab.__prefix__.to_s == prefix
        end
        #p k => vocab #ok
        if vocab.nil?
          raise "Don't know a vocabulary for prefix #{prefix.inspect} in CURIE #{prefix}:#{property}"
        end
        Vocabs[prefix] = vocab
        vocab
      end
      vocab[property]
    end

    def expand_curie(from)
      case from
      when Array
        case from.length
        when 2
          prefix, property = *from
          return interned_uri(expand_curie_pair(prefix.to_s, property.to_s))
        when 1
          return expand_curie(from.first)
        else
          return from
        end
      else
        return from
      end
    end

    def normalize_property(prefix, property = nil)
      if property.nil?
        property = prefix

        case property
        when Array
          normalize_property(*property)
        when String
          RDF::URI.intern(property)
        else
          property
        end
      else
        expand_curie([prefix, property])
      end
    end

    def root_url
      nil
    end

    def interned_uri(value)

      RDF::URI.intern(uri(value))
    end

    def uri(value)
      if root_url
        value = root_url.join(value)
      else
        value = RDF::URI.new(value)
      end

      if !value.query.nil? and value.query.empty?
        value.query = nil
      end
      value.validate!
      value.canonicalize!

      value
    end
  end

end
