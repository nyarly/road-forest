require 'roadforest/rdf/focus-wrapping'
module RoadForest::RDF
  class FocusList < ::RDF::List

    attr_accessor :root_url, :base_node, :source_rigor

    alias car first
    alias cdr rest

    def first
      at(0)
    end

    def each
      return to_enum unless block_given?
      super do |value|
        yield base_node.unwrap_value(value)
      end
    end

    def append(value)
      value = case value
        when nil         then RDF.nil
        when RDF::Value  then value
        when Array       then RDF::List.new(nil, graph, value)
        else value
      end

      if empty?
        new_subject = subject
      else
        old_subject, new_subject = last_subject, RDF::Node.new
        graph.delete([old_subject, RDF.rest, RDF.nil])
        graph.insert([old_subject, RDF.rest, new_subject])
      end

      graph.insert([new_subject, RDF.type, RDF.List])
      graph.insert([new_subject, RDF.first, value.is_a?(RDF::List) ? value.subject : value])
      graph.insert([new_subject, RDF.rest, RDF.nil])

      self
    end
    alias << append

    def append_node(subject=nil)
      base_node.create_node(subject) do |node|
        append(node.subject)
        yield node if block_given?
      end
    end
  end
end
