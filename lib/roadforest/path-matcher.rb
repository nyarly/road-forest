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

    class MatchEdge
      attr_accessor :parent
      attr_accessor :stem
      attr_accessor :repeats
      attr_accessor :pattern
      attr_accessor :graph

      attr_accessor :graph_term
      attr_accessor :pattern_step
      attr_accessor :edge_kind
      attr_accessor :predicate

      attr_reader :accepting_count, :rejecting_count

      def initialize
        @accepting_count = 0
        @rejecting_count = 0
        yield self
      end

      def pretty_print_instance_variables
        instance_variables.reject do |var|
          var == :@parent
        end
      end

      def matched_statements
        return {} unless accepting?
        @matched_statements ||=
          begin
            if rejecting?
              {}
            else
              child_nodes.map do |node|
                node.matched_statements
              end.inject({}) do |set, matched|
                set.merge(matched)
              end
            end
          end
      end

      def step_count
        repeats.fetch(pattern_step, 0) + 1
      end

      def step_maximum
        1
      end

      def node_excluded?
        step_count > step_maximum
      end

      def resolved?
        return false unless @opened
        @resolved ||=
          begin
            if rejecting?
              true
            else
              not child_nodes.any? do |node|
                not node.resolved?
              end
            end
          end
      end

      def min_fan
        1
      end

      def max_fan
        1
      end

      def rejecting?
        accepting_count > max_fan or available_count < min_fan
      end

      def accepting?
        resolved? and not rejecting?
      end


      def notify_resolved(child)
        @accepting_count += 1 if child.accepting?
        @rejecting_count += 1 if child.rejecting?
      end

      def available_count
        child_nodes.length - rejecting_count
      end

      def pattern_hash
        term = case edge_kind
               when Graph::Path.forward
                 :subject
               when Graph::Path.reverse
                 :object
               else
                 raise "Invalid Edge type: #{edge_kind.inspect}"
               end
        { :predicate => predicate, term => graph_term }
      end

      def graph_node(statement)
        case edge_kind
        when Graph::Path.forward
          statement.subject
        when Graph::Path.reverse
          statement.object
        else
          raise "Invalid Edge type: #{edge_kind.inspect}"
        end
      end

      def child_nodes
        @child_nodes ||=
          begin
            graph.query(pattern_hash).map do |statement|
              next if stem.has_key?(statement)

              MatchNode.new do |node|
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

      def open
        @opened = true
        if node_excluded?
          return []
        end

        return child_nodes
      end
    end

    class MatchNode
      attr_accessor :parent
      attr_accessor :stem #the path of statements from the root
      attr_accessor :repeats #the depth first count of repetitions of pattern nodes
      attr_accessor :pattern
      attr_accessor :graph

      attr_accessor :pattern_step #the node in the pattern graph
      attr_accessor :graph_term #the node in the matched graph
      attr_accessor :statement #the RDF statement that got here from parent

      def initialize
        yield self if block_given?
      end


      def pretty_print_instance_variables
        instance_variables.reject do |var|
          var == :@parent
        end
      end

      def matched_statements
        return {} unless resolved?
        @matched_statements ||=
          begin
            if rejecting?
              {}
            else
              statements = statement.nil? ? {} : { statement => true }
              child_edges.map do |edge|
                edge.matched_statements
              end.inject(statements) do |hash, graph|
                hash.merge(graph)
              end
            end
          end
      end

      def statement_excluded?
        stem.has_key?(statement)
      end

      def resolved?
        return false unless @opened
        @resolved ||= accepting? or rejecting?
      end

      def notify_resolved(child)

      end

      def accepting?
        @accepting ||=
          if statement_excluded?
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
            if statement_excluded?
              true
            else
              child_edges.any? do |edge|
                edge.rejecting?
              end
            end
          end
      end

      def edge_query_pattern(direction)
        pattern_node = pattern_step
        RDF::Query.new do
          pattern [ pattern_node, direction, :next ]
          pattern [ :next, Graph::Path.predicate, :predicate ]
        end
      end

      def find_child_edges(path_relation)
        pattern.query(edge_query_pattern(path_relation)).each_with_object([]) do |solution, edges|
          edges << MatchEdge.new do |edge|
            edge.pattern = pattern
            edge.graph = graph
            edge.parent = self
            edge.stem = stem.merge(self.statement => true)
            edge.repeats = self.repeats

            edge.edge_kind = path_relation
            edge.pattern_step = solution[:next]
            edge.predicate = solution[:predicate]
          end
        end
      end

      def child_edges
        @child_edges ||=
          begin
            edges = [Graph::Path.forward, Graph::Path.reverse ].map do |direction|
              find_child_edges(direction)
            end.inject do |edges, direction_list|
              edges + direction_list
            end
          end
      end

      def open
        @opened = true
        if statement_excluded?
          return []
        end

        return child_edges
      end
    end

    def initialize()
      reset
    end

    attr_accessor :pattern
    attr_reader :completed_child

    def match(root, graph)
      reset
      add_matching_nodes([MatchNode.new do |node|
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
        add_matching_nodes(matching.open)
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
