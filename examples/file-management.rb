require 'rdf/vocab/skos'

module FileManagementExample
  module Vocabulary
    class LC < ::RDF::Vocabulary("http://lrdesign.com/vocabularies/logical-construct#"); end
  end

  class ServicesHost < ::RoadForest::Application::ServicesHost
    attr_accessor :file_records, :destination_dir

    def initialize
      @file_records = []
    end
  end

  FileRecord = Struct.new(:name, :resolved)

  class Application < RoadForest::Application
    def setup
      router.add         :root,              [],                    :read_only,  Models::Navigation
      router.add         :unresolved_needs,  ["unresolved_needs"],  :parent,     Models::UnresolvedNeedsList
      router.add_traced  :need,              ["needs",'*'],         :leaf,       Models::Need
      router.add         :file_content,      ["files","*"],         :leaf,       Models::NeedContent
    end

    module Models
      class Navigation < RoadForest::RDFModel
        def exists?
          true
        end

        def update(graph)
          return false
        end

        def nav_entry(graph, name, path)
          graph.add_node([:skos, :hasTopConcept], "#" + name) do |entry|
            entry[:rdf, :type] = [:skos, "Concept"]
            entry[:skos, :label] = name
            entry[:foaf, "page"] = path
          end
        end

        def fill_graph(graph)
          graph[:rdf, "type"] = [:skos, "ConceptScheme"]
          nav_entry(graph, "Unresolved", path_for(:unresolved_needs))
        end
      end

      class UnresolvedNeedsList < RoadForest::RDFModel
        def exists?
          true
        end

        def update(graph)
        end

        def add_child(graph)
          new_file = FileRecord.new(graph.first(:lc, "name"), false)
          services.file_records << new_file
        end

        def fill_graph(graph)
          graph.add_list(:lc, "needs") do |list|
            services.file_records.each do |record|
              if !record.resolved
                list << path_for(:need, '*' => record.name)
              end
            end
          end
        end
      end

      class NeedContent < RoadForest::BlobModel
        add_type "text/plain", TypeHandlers::Handler.new
      end

      class Need < RoadForest::RDFModel
        def data
          @data = services.file_records.find do |record|
            record.name == params.remainder
          end
        end

        def graph_update(graph)
          data.resolved = graph[[:lc, "resolved"]]
          new_graph
        end

        def fill_graph(graph)
          graph[[:lc, "resolved"]] = data.resolved
          graph[[:lc, "name"]] = data.name
          graph[[:lc, "contents"]] = path_for(:file_content)
        end
      end
    end
  end
end
