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

      def success?
        @matcher.completed_child.accepting?
      end
      alias successful? success?
      alias succeed? success?

      def graph
        if success?
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
      attr_accessor :satified
      attr_accessor :pattern
      attr_accessor :graph
      attr_accessor :graph_term
      attr_accessor :pattern_step

      attr_reader :children

      def initialize
        @children = nil
        reset
        yield self
        @satisfied ||= {}
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
          return @children = []
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
      attr_accessor :min_multi, :max_multi, :min_repeat, :max_repeat

      alias child_nodes children

      def self.edge_query_pattern(pattern_node)
        path_direction = self.path_direction
        RDF::Query.new do
          pattern [ pattern_node, path_direction, :next ]
          pattern [ :next, Graph::Path.predicate, :predicate ]
          pattern [ :next, Graph::Path.minMulti,  :min_multi ], :optional => true
          pattern [ :next, Graph::Path.maxMulti,  :max_multi ], :optional => true
          pattern [ :next, Graph::Path.minRepeat,  :min_repeat ], :optional => true
          pattern [ :next, Graph::Path.maxRepeat,  :max_repeat ], :optional => true
        end
      end

      def to_s
        state = case
                when !resolved?
                  "?"
                when accepting?
                  "A"
                when rejecting?
                  "R"
                end
        "<#{self.class.name.sub(/.*::/,'')} #{predicate}*#{min_multi}-#{max_multi} #{min_repeat}-#{max_repeat}:#{step_count} #{state} >"
      end

      def step_count
        repeats.fetch(pattern_step, 0)
      end

      def excluded?
        step_count >= max_repeat
      end

      def satisfied?
        step_count >= min_repeat
      end

      def reset
        @accepting_count = 0
        @rejecting_count = 0
        @min_multi = 1
        @max_multi = 1
        @min_repeat = 1
        @max_repeat = 1
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
        return false if excluded?
        return false if satisfied?
        (not max_multi.nil? and accepting_count > max_multi) or available_count < min_multi
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
            node.repeats = self.repeats.merge({self.pattern_step => step_count + 1})
          end
        end
      end
    end

    class ForwardEdge < Edge
      def self.path_direction
        Graph::Path.forward
      end

      def pattern_hash
        { :predicate => predicate, :subject => graph_term }
      end

      def graph_node(statement)
        statement.object
      end
    end

    class ReverseEdge < Edge
      def self.path_direction
        Graph::Path.reverse
      end

      def pattern_hash
        { :predicate => predicate, :object => graph_term }
      end

      def graph_node(statement)
        statement.subject
      end
    end

    class Node < MatchStep
      attr_accessor :statement #the RDF statement that got here from parent

      alias child_edges children

      def to_s
        state = case
                when !resolved?
                  "?"
                when accepting?
                  "A"
                when rejecting?
                  "R"
                end
        "[#{self.class.name.sub(/.*::/,'')} #{statement} #{graph_term}/#{pattern_step} #{state} ]"
      end

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
        pattern.query(klass.edge_query_pattern(pattern_step)).map do |solution|
          klass.new do |edge|
            edge.pattern = pattern
            edge.graph = graph
            edge.parent = self
            edge.stem = stem.merge(self.statement => true)
            edge.repeats = self.repeats
            edge.graph_term = graph_term

            edge.pattern_step = solution[:next]
            edge.predicate = solution[:predicate]
            unless solution[:min_multi].nil? and solution[:max_multi].nil?
              edge.min_multi = solution[:min_multi].nil? ? 0 : solution[:min_multi].object
              edge.max_multi = solution[:max_multi].nil? ? nil : solution[:max_multi].object
            end
            unless solution[:min_repeat].nil? and solution[:max_repeat].nil?
              edge.min_repeat = solution[:max_repeat].nil? ? 0 : solution[:min_repeat].object
              edge.max_repeat = solution[:max_repeat].nil? ? nil : solution[:max_repeat].object
            end
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
        matching.open
        require 'pp'; puts "\n#{__FILE__}:#{__LINE__} => #{matching.pretty_inspect}"
        add_matching_nodes(matching.children)

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
        puts "\n#{__FILE__}:#{__LINE__} => #{matching.to_s}"
        matching.parent.notify_resolved(matching)
        matching = matching.parent
      end
    end
  end
end
