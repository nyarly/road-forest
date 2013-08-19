require 'rdf'
require 'roadforest/rdf/context-fascade'
require 'roadforest/rdf/focus-wrapping'
require 'roadforest/rdf/graph-reading'

module RoadForest::RDF
  class GraphCollection
    include Enumerable
  end

  class MultivaluedProperty < GraphCollection
    attr_reader :graph, :subject, :property
    def initialize(graph, subject, property)
      @graph, @subject, @propery = graph, subject, property
    end

    def values
      query_value(graph, subject, property)
    end

    def each
      if block_given?
        other
        values.each do |value|
          yield unwrap_value(value)
        end
      else
        values.each
      end
    end

    def add(value)
      add_statement(subject, property, value)
    end
  end

  module GraphWriting
    def normalize_triple(property, value, extra=nil)
      if not extra.nil?
        property = [property, value]
        value = extra
      end
      return normalize_property(property), normalize_term(value)
    end

    def set(property, value, extra=nil)
      property, value = normalize_triple(property, value, extra)

      delete(property)
      add(property, value)
      return value
    end
    alias_method :[]=, :set

    def add(property, value, extra=nil)
      property, value = normalize_triple(property, value, extra)

      target_graph.insert([subject, property, value])
      return value
    end

    def delete(property, extra=nil)
      target_graph.delete([subject, normalize_property(property, extra), :value])
    end

    def set_node(property, url=nil)
      node = wrap_node(set(property, normalize_resource(url) || RDF::Node.new))
      yield node if block_given?
      node
    end
    alias node_at set_node

    def add_node(property, url=nil)
      node = wrap_node(add(property, normalize_resource(url) || RDF::Node.new))
      yield node if block_given?
      node
    end

    def add_list(property, extra=nil)
      list = ::RDF::List.new(nil, target_graph)
      target_graph.insert([subject, normalize_property(property, extra), list.subject])
      yield list if block_given?
      return list
    end
  end

  class GraphFocus < GraphReading
    include GraphWriting

    def target_graph
      graph
    end

  end
end
