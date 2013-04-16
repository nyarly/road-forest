require 'rdf/vocab'
require 'atst/normalization'

module ATST
  #Steps provide an interface onto RDF that obscures somewhat the underlying
  #details of RDF.
  class Step
    include Normalization

    attr_accessor :walker, :subject
    alias rdf subject

    def initialize
      @walker = nil
      @subject = nil
    end

    def forward_properties
      query_properties do |query|
        query.pattern [ @subject, :property, :value ]
      end
    end

    def reverse_properties
      query_properties do |query|
        query.pattern [ :reverse, :property, @subject ]
      end
    end

    def get(property_or_prefix, property_value = nil)
      property =
        if property_value.nil?
          property_or_prefix
        else
          [property_or_prefix, property_value]
        end
      query_value(property) do |query|
        query.pattern [ @subject, normalize_property(property), :value]
      end
    end
    alias_method :[], :get

    def rev(property_or_prefix, property_value = nil)
      property =
        if property_value.nil?
          property_or_prefix
        else
          [property_or_prefix, property_value]
        end
      query_value(property) do |query|
        query.pattern [ :value, normalize_property(property), @subject]
      end
    end

    def set(property, value, extra=nil)
      if not extra.nil?
        property = [property, value]
        value = extra
      end
      walker.add_statement(@subject, normalize_property(property), value)
      return value
    end
    alias_method :[]=, :set

    def node_at(property, url=nil)
      wrap_node(set(property, normalize_resource(url) || RDF::Node.new))
    end

    def query_properties(&block)
      solutions = walker.query(&block)
      solutions.map do |solution|
        prop = solution["property"]
        if qname = prop.qname
          qname
        else
          prop
        end
      end
    end

    def query_value(property, &block)
      solutions = walker.query(&block)
      case solutions.length
      when 0
        raise NoSolutions, "No value found for #{property}"
      when 1
        return unwrap_value(solutions.first["value"])
      else
        raise AmbiguousSolutions, "Ambiguous solutions found for #{property}"
      end
    end

    def wrap_node(value)
      next_step = Step.new
      next_step.subject = value
      next_step.walker = walker
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
end
