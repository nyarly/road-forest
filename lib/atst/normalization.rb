module ATST
  module Normalization
    Vocabs = RDF::Vocabulary.each_with_object({}) do |vocab, hash|
      hash[vocab.__prefix__.to_s] = vocab
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
      when String
        from = uri(from)
      when Symbol
        from = RDF::Node.new(from)
      else
        from = RDF::Resource.new(from)
      end
      return from
    end

    def normalize_uri(from)
      from = expand_curie(from)
      case from
      when nil
      when RDF::URI
      else
        from = uri(from)
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

    def expand_curie(from)
      case from
      when Array
        prefix, property = *from
        return uri(Vocabs[prefix.to_s][property])
      else
        return from
      end
    end

    def normalize_property(property)
      case property
      when Array
        expand_curie(property)
      when String
        RDF::URI.intern(property)
      else
        property
      end
    end

    def root_url
      nil
    end

    def uri(value)
      if root_url
        value = root_url.join(value)
      else
        value = RDF::URI.new(value)
      end

      value.validate!
      value.canonicalize!
      value = RDF::URI.intern(value)

      value
    end
  end
end
