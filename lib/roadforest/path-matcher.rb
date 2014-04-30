require 'rdf'
require 'roadforest/graph/vocabulary'

module RoadForest
  class PathMatcher
    class Failure < ::StandardError; end
    class NoMatch < Failure; end

    class Match
      def initialize(matcher)
        @matcher = matcher
      end

      def graph
        if @matcher.completed_child.accepting?
          statements = @matcher.completed_child.matched_statements.keys
          ::RDF::Graph.new.tap do |graph|
            statements.each do |stmt|
              graph << stmt
            end
          end
        else
          raise NoMatch, "Pattern doesn't match graph"
        end
      end
    end

    class MatchStep
      attr_accessor :parent
      attr_accessor :stem
      attr_accessor :repeats
      attr_accessor :pattern
      attr_accessor :graph
      attr_accessor :graph_term
      attr_accessor :pattern_step

      attr_reader :children

      def initialize
        @children = nil
        reset
        yield self
        @stem ||= {}
        @repeats ||= {}
      end

      def reset
      end

      def pretty_print_instance_variables
        instance_variables.reject do |var|
          var == :@parent
        end
      end

      def immediate_match
        {}
      end

      def open
        if excluded?
          return []
        end

        @children ||= build_children

        return children
      end

      def matched_statements
        return {} unless accepting?
        @matched_statements ||=
          begin
            children.map do |child|
              child.matched_statements
            end.inject(immediate_match) do |set, matched|
              set.merge(matched)
            end
          end
      end
    end

    class Edge < MatchStep
      attr_accessor :predicate

      attr_reader :accepting_count, :rejecting_count

      alias child_nodes children

      def step_count
        repeats.fetch(pattern_step, 0) + 1
      end

      def step_maximum
        1
      end

      def excluded?
        step_count > step_maximum
      end

      def reset
        @accepting_count = 0
        @rejecting_count = 0
      end

      def min_fan
        1
      end

      def max_fan
        1
      end

      def notify_resolved(child)
        @accepting_count += 1 if child.accepting?
        @rejecting_count += 1 if child.rejecting?
      end

      def resolved?
        return false if children.nil?
        @resolved ||=
          begin
            if rejecting?
              true
            else
              not children.any? do |node|
                not node.resolved?
              end
            end
          end
      end

      def rejecting?
        return false if children.nil?
        accepting_count > max_fan or available_count < min_fan
      end

      def accepting?
        return false if children.nil?
        resolved? and not rejecting?
      end

      def available_count
        child_nodes.length - rejecting_count
      end

      def build_children
        graph.query(pattern_hash).map do |statement|
          next if stem.has_key?(statement)

          Node.new do |node|
            node.pattern = pattern
            node.graph = graph
            node.parent = self
            node.graph_term = graph_node(statement)
            node.pattern_step = pattern_step
            node.statement = statement
            node.stem = stem
            node.repeats = self.repeats.merge({self.pattern_step => step_count})
          end
        end
      end
    end

    class ForwardEdge < Edge
      def self.edge_query_pattern(pattern_node)
        RDF::Query.new do
          pattern [ pattern_node, Graph::Path.forward, :next ]
          pattern [ :next, Graph::Path.predicate, :predicate ]
        end
      end

      def pattern_hash
        { :predicate => predicate, :subject => graph_term }
      end

      def graph_node(statement)
        statement.subject
      end
    end

    class ReverseEdge < Edge
      def self.edge_query_pattern(pattern_node)
        RDF::Query.new do
          pattern [ pattern_node, Graph::Path.reverse, :next ]
          pattern [ :next, Graph::Path.predicate, :predicate ]
        end
      end

      def pattern_hash
        { :predicate => predicate, :object => graph_term }
      end

      def graph_node(statement)
        statement.object
      end
    end

    class Node < MatchStep
      attr_accessor :statement #the RDF statement that got here from parent

      alias child_edges children

      def immediate_match
        statement.nil? ? {} : { statement => true }
      end

      def excluded?
        stem.has_key?(statement)
      end

      def notify_resolved(child)

      end

      def resolved?
        return false if @children.nil?
        @resolved ||= accepting? or rejecting?
      end

      def accepting?
        @accepting ||=
          if excluded?
            false
          elsif children.nil?
            false
          else
            child_edges.all? do |edge|
              edge.accepting?
            end
          end
      end

      def rejecting?
        @rejecting ||=
          begin
            if excluded?
              true
            elsif children.nil?
              false
            else
              child_edges.any? do |edge|
                edge.rejecting?
              end
            end
          end
      end

      def find_child_edges(klass)
        pattern.query(klass.edge_query_pattern(pattern_step)).each_with_object([]) do |solution, edges|
          edges << klass.new do |edge|
            edge.pattern = pattern
            edge.graph = graph
            edge.parent = self
            edge.stem = stem.merge(self.statement => true)
            edge.repeats = self.repeats

            edge.pattern_step = solution[:next]
            edge.predicate = solution[:predicate]
          end
        end
      end

      def build_children
        edges = [ForwardEdge, ReverseEdge ].map do |klass|
          find_child_edges(klass)
        end.inject do |edges, direction_list|
          edges + direction_list
        end
      end
    end

    def initialize()
      reset
    end

    attr_accessor :pattern
    attr_reader :completed_child

    def match(root, graph)
      reset
      add_matching_nodes([Node.new do |node|
        node.parent = self
        node.stem = {}
        node.repeats = {}
        node.pattern = pattern
        node.graph = graph

        node.statement = nil
        node.graph_term = root
        node.pattern_step = pattern_root
      end
      ])
      search_iteration until complete?
      return Match.new(self)
    end

    def reset
      @search_queue = []
      @completed_child = nil
    end

    def pattern_root
      @pattern_root ||=
        begin
          roots = pattern.query(:predicate => RDF::RDFS.class, :object => Graph::Path.Root).to_a
          if roots.length != 1
            raise "A pattern should have exactly one root, has: #{roots.length}\n#{roots.map(&:inspect).join('\n')}"
          end
          roots.first.subject
        end
    end

    def complete?
      !@completed_child.nil? or @search_queue.empty?
    end

    def notify_resolved(matching)
      @completed_child = matching
    end

    def search_iteration
      matching = next_matching_node
      unless matching.nil?
        require 'pp'
        matching.open
        add_matching_nodes(matching.children)
        puts "\n#{__FILE__}:#{__LINE__} => #{matching.pretty_inspect}"

        check_complete(matching)
      end
    end

    def next_matching_node
      @search_queue.pop #simple depth first
    end

    def add_matching_nodes(list)
      @search_queue += list
    end

    def resolved?
      false
    end

    def check_complete(matching)
      while matching.resolved?
        matching.parent.notify_resolved(matching)
        matching = matching.parent
      end
    end
  end
end
