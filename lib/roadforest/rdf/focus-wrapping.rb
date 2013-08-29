require 'rdf/model/node'
require 'roadforest/rdf'

module RoadForest::RDF
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
      next_step.graph = graph
      next_step.source_rigor = source_rigor
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
  end
end
