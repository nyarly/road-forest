require 'road-forest/application'

module RoadForest
  class Application
    #The results of processing an RDF update - could include a new graph, or a
    #different resource (url) to look at
    class Results
      attr_accessor :graph, :subject_resource, :go_to_resource

      def initialize(subject=nil, graph=nil)
        @graph, @subject_resource = graph, subject
        yield self if block_given?
      end

      def start_graph(resource=nil)
        @graph ||= ::RDF::Graph.new
        focus = RDF::GraphFocus.new
        focus.graph_store = @graph
        focus.subject = resource || @subject_resource

        yield focus if block_given?
        return focus
      end

      def absolutize(root_uri)
        @graph.each_statement do |statement|
          original = statement.dup
          if ::RDF::URI === statement.subject and statement.subject.relative?
            statement.subject = root_uri.join(statement.subject)
          end

          if ::RDF::URI === statement.object and statement.object.relative?
            statement.object = root_uri.join(statement.object)
          end

          if statement != original
            @graph.delete(original)
            @graph.insert(statement)
          end
        end
      end
    end
  end
end
