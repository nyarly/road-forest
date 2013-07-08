require 'road-forest/rdf/graph-focus'
require 'road-forest/rdf/parcel'

module RoadForest::RDF
  class UpdateFocus < GraphFocus
    attr_accessor :target_graph

    alias source_graph graph_manager
    alias source_graph= graph_manager=

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
        puts; puts "#{__FILE__}:#{__LINE__} => #{(:copy).inspect}"
        puts "#{__FILE__}:#{__LINE__} => #{(root_url).inspect}"
        puts "#{__FILE__}:#{__LINE__} => #{(target_graph.contexts.to_a).inspect}"
        parceller.graph_for(root_url).each_statement do |statement|
          statement.context = root_url
          target_graph << statement
          puts; puts "#{__FILE__}:#{__LINE__} => #{(statement.context).inspect}"
          puts "#{__FILE__}:#{__LINE__} => #{(target_graph.contexts.to_a).inspect}"
        end
        puts; puts "#{__FILE__}:#{__LINE__} => #{(target_graph.statements.map(&:context)).inspect}"
        puts "#{__FILE__}:#{__LINE__} => #{(target_graph.contexts.to_a).inspect}"
      end
    end

    def add(property, value, extra=nil)
      copy_context
      puts; puts "#{__FILE__}:#{__LINE__} => #{(:add).inspect}"
      property, value = normalize_triple(property, value, extra)
      target_graph.insert([subject, property, value, root_url])
    end

    def set(property, value, extra=nil)
      copy_context
      super
    end

    def delete(property, extra=nil)
      copy_context
      puts; puts "#{__FILE__}:#{__LINE__} => #{(:delete).inspect}"
      property, value = normalize_triple(property, value, extra)
      target_graph.query([subject, property]) do |statement|
        puts; puts "#{__FILE__}:#{__LINE__} => #{(statement).inspect}"
        target_graph.delete(statement)
      end
    end
  end
end
