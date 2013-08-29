require 'roadforest/rdf/graph-focus'
require 'roadforest/rdf/parcel'

module RoadForest::RDF
  class UpdateFocus < GraphFocus
    attr_accessor :target_graph

    alias source_graph= graph=
    alias source_graph graph

    def dup
      other = super
      other.target_graph = target_graph
      other
    end

    def parceller
      @parceller ||=
        begin
          parceller = Parcel.new
          parceller.graph = source_graph
          parceller
        end
    end

    def copy_context
      unless target_graph.has_context?(root_url)
        parceller.graph_for(root_url).each_statement do |statement|
          statement.context = root_url
          target_graph << statement
        end
      end
    end

    def relevant_prefixes
      super.merge(relevant_prefixes_for_graph(target_graph))
    end

    def add(property, value, extra=nil)
      copy_context
      property, value = normalize_triple(property, value, extra)
      target_graph.insert([subject, property, value, root_url])
    end

    def set(property, value, extra=nil)
      copy_context
      super
    end

    def delete(property, extra=nil)
      copy_context
      property, value = normalize_triple(property, value, extra)
      target_graph.query([subject, property]) do |statement|
        target_graph.delete(statement)
      end
    end

    def query_value(query)
      source_result = super
      target_result = query.execute(target_graph).map do |solution|
        unwrap_value(solution.value)
      end

      if target_result.empty?
        source_result
      else
        target_result
      end
    end

    def wrap_node(value)
      focus = super
      focus.target_graph = self.target_graph
      focus
    end
  end
end
