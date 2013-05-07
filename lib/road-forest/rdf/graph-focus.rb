require 'rdf'
require 'road-forest/rdf'
require 'road-forest/rdf/normalization'
require 'road-forest/rdf/creates-graph'

module RoadForest::RDF
  class GraphReading
    include Normalization

    attr_accessor :graph_manager, :subject, :query_manager
    alias rdf subject

    def initialize
      @graph_manager = nil
      @subject = nil
      @query_manager = nil
    end

    def forward_properties
      query_properties( [ subject, :property, :value ] )
    end

    def reverse_properties
      query_properties( [ :reverse, :property, subject ] )
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

    def rev(prefix, property = nil)
      return single_or_enum(reverse_query_value( prefix, property))
    end

    def rev_first(prefix, property = nil)
      return reverse_query_value(prefix, property).first
    end

    def rev_all(prefix, property = nil)
      return reverse_query_value(prefix, property)
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

    def wrap_node(value)
      next_step = self.class.new
      next_step.subject = value
      next_step.graph_manager = graph_manager
      next_step.query_manager = query_manager
      next_step
    end

    def unwrap_value(value)
      if value.respond_to? :object
        value.object
      else
        wrap_node(value)
      end
    end

    def query_properties(pattern)
      solutions = query_manager.query(graph_manager, subject, pattern)
      solutions.map do |solution|
        prop = solution.property
        if qname = prop.qname
          qname
        else
          prop
        end
      end
    end
  end

  class GraphFocus < GraphReading
    include CreatesGraph

    def sub_graph
      sub = new_graph(subject)

      builder = GraphBuilder.new
      builder.graph_manager = graph_manager
      builder.subject = subject
      builder.query_manager = query_manager

      builder.destination_graph = sub.graph_manager

      yield builder

      return sub
    end

    def set(property, value, extra=nil)
      if not extra.nil?
        property = [property, value]
        value = extra
      end

      delete(normalize_property(property))
      add(property, value)
      return value
    end
    alias_method :[]=, :set

    def add(property, value, extra=nil)
      # Begin able to step[value] << would be neat...
      if not extra.nil?
        property = [property, value]
        value = extra
      end
      graph_manager.add_statement(subject, normalize_property(property), value)
      return value
    end

    def delete(property, extra=nil)
      graph_manager.delete_statements([subject, normalize_property(property, extra)])
    end

    def node_at(property, url=nil)
      wrap_node(set(property, normalize_resource(url) || RDF::Node.new))
    end

    protected

    def reverse_query_value(prefix, property=nil)
      query_value([ :value, normalize_property(prefix, property), subject])
    end

    def forward_query_value(prefix, property=nil)
      query_value([ subject, normalize_property(prefix, property), :value])
    end

    def query_value(pattern)
      solutions = query_manager.query(graph_manager, subject, pattern)
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
