require 'roadforest/graph/access-manager'
require 'roadforest/source-rigor/resource-query'
require 'roadforest/source-rigor/resource-pattern'
require 'roadforest/source-rigor/parcel'
require 'roadforest/path-matcher'

module RoadForest
  module SourceRigor
    module Rigorous
      Af = Graph::Af

      attr_accessor :rigor

      def dup
        other = self.class.allocate
        other.resource = self.resource
        other.rigor = self.rigor
        other.source_graph = self.source_graph

        return other
      end

      def build_query
        ResourceQuery.new([], {}) do |query|
          query.subject_context = resource
          query.source_rigor = rigor
          yield query
        end
      end

      def query_execute(query, &block)
        query = ResourceQuery.from(query, resource, rigor)
        execute_search(query, &block)
      end

      def resource_pattern_from(pattern)
        ResourcePattern.from(pattern, {:context_roles => {:subject => resource}, :source_rigor => rigor})
      end

      def query_pattern(pattern, &block)
        execute_search(resource_pattern_from(pattern), &block)
      end

      def delete(statement)
        statement = resource_pattern_from(statement)
        destination_graph.delete(statement)
      end
    end

    class RetrieveManager < Graph::ReadOnlyManager
      include Rigorous
    end

    class PostManager < Graph::WriteManager
      include Rigorous
    end

    class UpdateManager < Graph::SplitManager
      include Rigorous

      def initialize
        @copied_contexts = {}
        @inserts = Hash.new{|h,k| h[k] = []}
        @deletes = Hash.new{|h,k| h[k] = []}
      end

      def reset
        super

        @copied_contexts.clear
        @inserts.clear
        @deletes.clear

        source_graph.each_statement do |stmt|
          target_graph << stmt
        end
      end

      attr_accessor :copied_contexts, :inserts, :deletes

      def dup
        other = super
        other.copied_contexts = self.copied_contexts
        other.inserts = self.inserts
        other.deletes = self.deletes
        other.target_graph = self.target_graph
        return other
      end

      def execute_search(search, &block)
        destination_enum = search.execute(destination_graph)
        source_enum = search.execute(origin_graph)

        enum = destination_enum.any?{ true } ? destination_enum : source_enum

        enum.each(&block)
        return enum
      end

      def record_insert(statement)
        @inserts[statement] << resource
      end

      def record_delete(statement)
        @deletes[statement] << resource
      end

      def statement_from(statement)
        ::RDF::Statement.from(statement)
      end

      def insert(statement)
        statement = statement_from(statement)
        record_insert(statement)
        statement.context ||= ::RDF::URI.intern("urn:local-insert")
        super
      end

      def delete(statement)
        statement = statement_from(statement)
        record_delete(statement)
        super
      end

      def each_payload
        update_payload_query = ::RDF::Query.new do
          pattern [ :affordance, Af.target, :resource ]
          pattern [ :affordance, Af.payload, :pattern_root ]
          pattern [ :affordance, RDF.type, Af.Update ]
        end
        query(update_payload_query).each do |solution|
          yield(solution[:resource], parceller.graph_for(solution[:pattern_root]))
        end
      end

      def each_target
        all_subjects = Hash[destination_graph.subjects.map{|s| [s,true]}]
        source_graph.subjects.each do |s|
          all_subjects[s] = true
        end
        check_inserts = inserts.dup
        check_deletes = deletes.dup
        marked_inserts = []
        marked_deletes = []

        each_payload do |root, graph_pattern|
          next unless all_subjects.has_key?(root)

          marked_inserts.clear
          marked_deletes.clear

          matcher = PathMatcher.new
          matcher.pattern = graph_pattern

          source_match = matcher.match(root, source_graph)

          dest_match = matcher.match(root, destination_graph)

          if dest_match.successful?
            check_inserts.each_key do |stmt|
              if dest_match.graph.has_statement?(stmt)
                marked_inserts << stmt
              end
            end
          end

          if source_match.successful?
            check_deletes.each_key do |stmt|
              if source_match.graph.has_statement?(stmt)
                marked_deletes << stmt
              end
            end
          end

          if dest_match.successful?
            if !source_match.successful? || (source_match.graph != dest_match.graph)

              yield(root, dest_match.graph)

              marked_inserts.each do |stmt|
                check_inserts.delete(stmt)
              end
              marked_deletes.each do |stmt|
                check_deletes.delete(stmt)
              end
            end
          end
        end

        fallback_needed = {}
        check_inserts.each_value do|resources|
          resources.each {|resource| fallback_needed[resource] = true }
        end
        check_deletes.each_value do|resources|
          resources.each {|resource| fallback_needed[resource] = true }
        end

        fallback_needed.each_key do |key|
          yield(key, parceller.graph_for(key))
        end
      end

      def parceller
        @parceller ||=
          begin
            parceller = Parcel.new
            parceller.graph = destination_graph
            parceller
          end
      end
    end
  end
end
