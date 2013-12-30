require 'rdf'
require 'rdf/model/node'
require 'roadforest/rdf'
require 'roadforest/rdf/focus-list'
require 'roadforest/rdf/normalization'
require 'roadforest/rdf/resource-query'
require 'roadforest/rdf/access-manager'


module RoadForest::RDF
  class NullFocus < ::BasicObject
    def initialize(focus, pattern, callsite)
      @focus, @pattern, @callsite = focus, pattern, callsite
    end

    def __callsite__
      @callsite
    end

    def subject
      @focus.subject
    end

    def nil?
      true
    end

    def blank?
      true
    end

    def empty?
      true
    end

    def length
      0
    end
    alias count length
    alias size length

    def method_missing(method, *args, &block)
      ::Kernel.raise ::NoMethodError, "No method '#{method}' on NullFocus. " +
        "NullFocus returned because there were no results at \n#{@focus.subject}\n  for \n#{@pattern.inspect}\n" +
        "Search was attempted at #{@callsite[0]}"
    end
  end

  class GraphFocus
    #XXX Any changes to this class heirarchy or to ContextFascade should start
    #with a refactor like:
    #  Reduce this to the single-node API ([] []=)
    #  Change the ContextFascade into a family of classes (RO, RW, Update)
    include Normalization

    #attr_accessor :source_graph, :target_graph, :subject, :root_url,
    #:source_rigor

    attr_accessor :subject, :access_manager

    alias rdf subject

    def initialize(access_manager, subject = nil)
      @access_manager = access_manager
      self.subject = subject unless subject.nil?
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
      "#<#{self.class.name}:0x#{"%x" % object_id} s:(#{subject.to_s}) p->o:#{forward_properties.inspect}>" #ok
    end
    alias to_s inspect

    def dup
      other = self.class.new(access_manager.dup)
      other.subject = subject
      other
    end

    ### Begin old GraphFocus
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
    alias first_or_add find_or_add

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
      list = FocusList.new(::RDF::Node.new, access_manager)
      access_manager.insert([subject, normalize_property(property, extra), list.subject])
      yield list if block_given?
      return list
    end
    #### End of old GraphFocus

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
      if RDF::Literal === value
        value.object
      elsif value == RDF.nil
        nil
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
      access_manager.relevant_prefixes
    end

    def get(prefix, property = nil)
      return maybe_null( prefix, property,
        single_or_enum(forward_query_value( prefix, property))
      )
    end
    alias_method :[], :get

    def first(prefix, property = nil)
      return maybe_null( prefix, property,
        forward_query_value( prefix, property ).first
      )
    end

    def all(prefix, property = nil)
      return  maybe_null( prefix, property,
        forward_query_value( prefix, property )
      )
    end

    #XXX Maybe rev should return a decorator, so it looks like:
    #focus.rev.get(...) or focus.rev.all(...)
    def rev(prefix, property = nil)
      return maybe_null( prefix, property,
        single_or_enum(reverse_query_value( prefix, property))
      )
    end

    def rev_first(prefix, property = nil)
      return maybe_null( prefix, property,
        reverse_query_value(prefix, property).first
      )
    end

    def rev_all(prefix, property = nil)
      return maybe_null( prefix, property,
        reverse_query_value(prefix, property)
      )
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

    STRIP_TRACE = %r{\A#{File::expand_path("../../..", __FILE__)}}
    def maybe_null(prefix, property, result)
      if not result.nil?
        if result.respond_to? :empty?
          return result unless result.empty?
        else
          return result
        end
      end
      return NullFocus.new(self, normalize_property(prefix, property), caller(0).drop_while{|line| line =~ STRIP_TRACE})
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

    def execute_query(query)
      query.execute(access_manager)
    end

    def query_value(query)
      solutions = execute_query(query)
      solutions.map do |solution|
        unwrap_value(solution.value)
      end
    end

    def query_properties(query)
      Hash[execute_query(query).map do |solution|
        prop = solution.property
        if qname = prop.qname
          prop = qname
        end
        [prop, solution.value]
      end]
    end
  end
end
