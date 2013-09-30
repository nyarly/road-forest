require 'rdf'
require 'roadforest/rdf/context-fascade'
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

  class GraphWriting < GraphReading
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

      access_manager.insert([subject, property, value])
      return value
    end

    def delete(property, extra=nil)
      access_manager.delete(:subject => subject, :predicate => normalize_property(property, extra))
    end

    def find_or_add(property, url=nil, &block)
      value = first(property)
      if value.nil?
        value = add_node(property, url, &block)
      else
        yield value if block_given?
      end
      value
    end

    def set_node(property, url=nil)
      create_node(url) do |node|
        set(property, node.subject)
        yield node if block_given?
      end
    end
    alias node_at set_node

    def add_node(property, url=nil)
      create_node(url) do |node|
        add(property, node.subject)
        yield node if block_given?
      end
    end

    #Create a subject node without relationship to the rest of the graph
    def create_node(url=nil)
      node = wrap_node(normalize_resource(url))
      yield node if block_given?
      node
    end

    def add_list(property, extra=nil)
      list = FocusList.new(nil, access_manager)
      access_manager.insert([subject, normalize_property(property, extra), list.subject])
      yield list if block_given?
      return list
    end
  end

  class GraphFocus < GraphWriting
    def target_graph
      @access_manager.target_graph
    end

    def source_graph=(graph)
      @access_manager.source_graph = graph
      @access_manager.target_graph = graph
    end
    alias target_graph= source_graph=

    alias graph source_graph
    alias graph= source_graph=
  end
end
