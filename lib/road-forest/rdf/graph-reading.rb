require 'road-forest/rdf/focus-list'
require 'road-forest/rdf/normalization'
require 'road-forest/rdf/focus-wrapping'
require 'road-forest/rdf/resource-query'

module RoadForest::RDF
  class GraphReading
    include Normalization
    include FocusWrapping

    attr_accessor :graph, :subject, :root_url, :source_rigor
    alias rdf subject

    def initialize(subject = nil, graph = nil, rigor = nil)
      @graph = nil
      @subject = nil
      @root_url = nil
      @source_rigor = nil
      self.subject = subject unless subject.nil?
      self.graph = graph unless graph.nil?
      self.source_rigor = rigor unless rigor.nil?
    end

    def dup
      other = self.class.new
      other.graph = graph
      other.subject = subject
      other.root_url = root_url
      other.source_rigor = source_rigor
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
        query.source_rigor = @source_rigor
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
      graph = ContextFascade.new(@graph, @root_url, @source_rigor)
      list = FocusList.new(@subject, graph)
      list.base_node = self
      list.source_rigor = source_rigor
      list
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
      solutions = query.execute(graph)
      solutions.map do |solution|
        unwrap_value(solution.value)
      end
    end
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
      query.execute(graph).map do |solution|
        prop = solution.property
        if qname = prop.qname
          qname
        else
          prop
        end
      end
    end
  end
end
