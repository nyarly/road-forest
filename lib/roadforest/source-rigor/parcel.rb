require 'roadforest/rdf'
require 'roadforest/graph/normalization'

module RoadForest
  class SourceRigor::Parcel
    include Graph::Normalization

    attr_accessor :graph

    def resources
      resource_hash = {}
      graph.each_subject do |subject|
        next unless RDF::URI === subject
        resource_hash[normalize_context(subject)] = true
      end
      resource_hash.keys
    end

    def subjects_for_resource(resource)
      resource = normalize_context(resource)
      graph.each_subject.find_all do |subject|
        normalize_context(subject) == resource
      end
    end

    def graph_for(resource)
      new_graph = RDF::Graph.new
      subjects = {}
      subjects_for_resource(resource).each do |subject|
        subjects[subject] ||= :open
      end

      until (open_subjects = subjects.keys.find_all{|subject| subjects[subject] == :open }).empty?
        open_subjects.each do |subject|
          subjects[subject] = :closed
          graph.query(:subject => subject) do |statement|
            if RDF::Node === statement.object
              subjects[statement.object] ||= :open
            end
            new_graph << statement
          end
        end
      end
      new_graph
    end
  end
end
