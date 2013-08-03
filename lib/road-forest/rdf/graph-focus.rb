require 'rdf'
require 'road-forest/rdf'
require 'road-forest/rdf/normalization'
require 'road-forest/rdf/creates-graph'
require 'road-forest/rdf/contextual-query'

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

  module FocusWrapping
    def new_focus
      dup
    end

    def wrap_node(value)
      next_step = new_focus
      if ::RDF::Node === value
        next_step.root_url = self.root_url
      else
        next_step.root_url = normalize_context(value)
      end
      next_step.subject = value
      next_step.graph_manager = graph_manager
      next_step.source_skepticism = source_skepticism
      next_step
    end

    def unwrap_value(value)
      if value.respond_to? :object
        value.object
      else
        wrap_node(value)
      end
    end
  end

  class FocusList < ::RDF::List
    include Normalization
    include FocusWrapping

    alias graph_manager graph

    attr_accessor :root_url, :base_node, :source_skepticism

    def new_focus
      base_node.dup
    end

    def each
      super do |value|
        yield unwrap_value(value)
      end
    end
  end

  class GraphReading
    include Normalization
    include FocusWrapping

    attr_accessor :graph_manager, :subject, :root_url, :source_skepticism, :graph_transfer
    alias rdf subject

    def initialize
      @graph_manager = nil
      @subject = nil
      @root_url = nil
      @source_skepticism = nil
      @graph_transfer = nil
    end

    def dup
      other = self.class.new
      other.graph_manager = graph_manager
      other.subject = subject
      other.root_url = root_url
      other.source_skepticism = source_skepticism
      other.graph_transfer = graph_transfer
      other
    end

    def root_url=(*value) #XXX curies?
      @root_url = normalize_resource(value)
    end

    def subject=(*value)
      @subject = normalize_resource(value)
      case @subject
      when ::RDF::URI
        @root_url ||= @subject
      end
    end

    def build_query
      ResourceQuery.new([], {}) do |query|
        query.subject_context = @root_url
        query.source_skepticism = @source_skepticism
        query.graph_transfer = graph_transfer
        yield query
      end
    end

    def forward_properties
      query_properties( build_query{|q| q.pattern([ normalize_resource(subject), :property, :value ])} )
    end

    def reverse_properties
      query_properties( build_query{|q| q.pattern([ :value, :property, normalize_resource(subject)])} )
    end

    def get(prefix, property = nil)
      return single_or_enum(forward_query_value( prefix, property))
    end
    alias_method :[], :get

    def first(prefix, property = nil)
      return forward_query_value( prefix, property ).first
    end

    def all(prefix, property = nil)
      return forward_query_value( prefix, property )
    end

    #XXX Maybe rev should return a decorator, so it looks like:
    #focus.rev.get(...) or focus.rev.all(...)
    def rev(prefix, property = nil)
      return single_or_enum(reverse_query_value( prefix, property))
    end

    def rev_first(prefix, property = nil)
      return reverse_query_value(prefix, property).first
    end

    def rev_all(prefix, property = nil)
      return reverse_query_value(prefix, property)
    end

    def as_list
      graph = ContextFascade.new(@graph_manager, @root_url, @source_skepticism)
      list = FocusList.new(@subject, graph)
      list.base_node = self
      list.source_skepticism = source_skepticism
      list
    end

    protected
    def single_or_enum(values)
      case values.length
      when 0
        return nil
      when 1
        return values.first
      else
        return values.enum_for(:each)
      end
    end

    def query_properties(query)
      query.execute(graph_manager).map do |solution|
        prop = solution.property
        if qname = prop.qname
          qname
        else
          prop
        end
      end
    end
  end

  module GraphWriting
    def normalize_triple(property, value, extra=nil)
      if not extra.nil?
        property = [property, value]
        value = extra
      end
      return normalize_property(property), value
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
    include CreatesGraph
    include GraphWriting

    def target_graph
      graph_manager
    end

    def sub_graph
      sub = new_graph(subject)

      builder = GraphBuilder.new
      builder.graph_manager = graph_manager
      builder.subject = subject

      builder.destination_graph = sub.graph_manager
      return sub
    end

    protected

    def reverse_query_value(prefix, property=nil)
      query_value(build_query{|q|
        q.pattern([ :value, normalize_property(prefix, property), normalize_resource(subject)])
      })
    end

    def forward_query_value(prefix, property=nil)
      query_value(build_query{|q|
        q.pattern([ normalize_resource(subject), normalize_property(prefix, property), :value])
      })
    end

    def query_value(query)
      solutions = query.execute(graph_manager)
      solutions.map do |solution|
        unwrap_value(solution.value)
      end
    end
  end

  class GraphBuilder < GraphReading
    attr_accessor :destination_graph

    def initialize
      @destination_graph = nil
    end

    protected

    def copy_statements(pattern)
      statements = query_manager.find_statements(graph_manager, subject, pattern)
      statements.each do |statement|
        destination_graph.insert_statement(statement)
      end
    end

    def reverse_query_value(prefix, property=nil)
      statements = copy_statements([:subject, normalize_property(prefix, property), subject])
      statements.map do |statement|
        unwrap_value(statement.subject)
      end
    end

    def forward_query_value(prefix, property=nil)
      statements = copy_statements([subject, normalize_property(prefix, property), :object])
      statements.map do |statement|
        unwrap_value(statement.object)
      end
    end
  end
end
