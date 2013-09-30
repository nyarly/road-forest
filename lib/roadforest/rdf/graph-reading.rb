require 'roadforest/rdf/focus-list'
require 'roadforest/rdf/normalization'
require 'roadforest/rdf/resource-query'
require 'rdf/model/node'
require 'roadforest/rdf'


module RoadForest::RDF
  class GraphReading
    #XXX Any changes to this class heirarchy or to ContextFascade should start
    #with a refactor like:
    #  Reduce this to the single-node API ([] []=)
    #  Change the ContextFascade into a family of classes (RO, RW, Update)
    include Normalization

    #attr_accessor :source_graph, :target_graph, :subject, :root_url,
    #:source_rigor

    attr_accessor :subject, :access_manager

    alias rdf subject

    def initialize(subject = nil, graph = nil, rigor = nil)
      @access_manager = ContextFascade.new
      @access_manager.rigor = rigor
      self.target_graph = graph
      self.source_graph = graph

      self.subject = subject unless subject.nil?
    end

    def source_graph
      @access_manager.source_graph
    end

    def source_graph=(graph)
      @access_manager.source_graph = graph
    end

    def target_graph
      nil
    end

    def target_graph=(graph)
      @access_manager.target_graph = nil
    end

    def source_rigor
      @access_manager.rigor
    end

    def source_rigor=(rigor)
      @access_manager.rigor = rigor
    end

    def root_url
      @access_manager.resource
    end

    def subject=(*value)
      @subject = normalize_resource(value)
      case @subject
      when ::RDF::URI
        @access_manager.resource = @subject
      end
    end

    def inspect
      "#<#{self.class.name}:0x#{"%x" % object_id} (#{subject.to_s}) #{forward_properties.inspect}>"
    end
    alias to_s inspect

    def dup
      other = self.class.new
      other.access_manager = access_manager.dup
      other.subject = subject
      other
    end

    def wrap_node(value)
      next_step = dup
      if ::RDF::Node === value
        next_step.root_url = self.root_url
      else
        next_step.root_url = normalize_context(value)
      end
      next_step.subject = value
      next_step
    end

    def unwrap_value(value)
      return nil if value.nil?
      if value.respond_to? :object
        value.object
      else
        wrap_node(value)
      end
    end

    def to_context
      normalize_context(subject)
    end

    def root_url=(*value) #XXX curies?
      @root_url = normalize_resource(value)
    end

    #XXX This probably wants to be handled completely in the MediaType handler
    def relevant_prefixes
      relevant_prefixes_for_graph(source_graph)
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
      list = FocusList.new(subject, access_manager)
      list.base_node = self
      list
    end

    def forward_properties
      query_properties( build_query{|q| q.pattern([ normalize_resource(subject), :property, :value ])} )
    end

    def reverse_properties
      query_properties( build_query{|q| q.pattern([ :value, :property, normalize_resource(subject)])} )
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

    def build_query(&block)
      access_manager.build_query(&block)
    end

    def query_value(query)
      solutions = query.execute(access_manager)
      solutions.map do |solution|
        unwrap_value(solution.value)
      end
    end

    def query_properties(query)
      Hash[query.execute(access_manager).map do |solution|
        prop = solution.property
        if qname = prop.qname
          prop = qname
        end
        [prop, solution.value]
      end]
    end
  end
end
