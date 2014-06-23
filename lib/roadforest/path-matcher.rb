require 'rdf'
require 'roadforest/graph/vocabulary'

module RoadForest
  class PathMatcher
    class Failure < ::StandardError; end
    class NoMatch < Failure; end

    class Match
      def initialize(matcher)
        @success = matcher.completed_child.accepting?
        @graph = if @success
            statements = matcher.completed_child.matched_statements.keys
            ::RDF::Graph.new.tap do |graph|
              statements.each do |stmt|
                graph << stmt
              end
            end
          end
      end

      def success?
        @success
      end
      alias successful? success?
      alias succeed? success?

      def graph
        if success?
          @graph
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

      attr_accessor :exact_value, :before, :after, :order, :type

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

      class << self
        def find_child_edges(node)
          node.pattern.query(edge_query_pattern(node.pattern_step)).map do |solution|
            new do |edge|
              edge.from(node, solution)
            end
          end
        end

        def edge_query_pattern(pattern_node)
          path_direction = self.path_direction
          RDF::Query.new do
            pattern  [  pattern_node, path_direction, :next ]
            pattern  [  :next,  Graph::Path.predicate,  :predicate   ]
            pattern  [  :next,  Graph::Path.minMulti,   :min_multi   ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.maxMulti,   :max_multi   ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.minRepeat,  :min_repeat  ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.maxRepeat,  :max_repeat  ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.is,         :exact_value ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.after,      :after       ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.before,     :before      ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.order,      :order       ],  :optional  =>  true
            pattern  [  :next,  Graph::Path.type,       :type        ],  :optional  =>  true
          end
        end
      end

      def from(node, solution)
        self.parent = node

        self.pattern = node.pattern
        self.graph = node.graph

        self.stem = node.stem.merge(node.statement => true)
        self.repeats = node.repeats
        self.graph_term = node.graph_term

        self.predicate = solution[:predicate]
        unless solution[:min_multi].nil? and solution[:max_multi].nil?
          self.min_multi = solution[:min_multi].nil? ? 0 : solution[:min_multi].object
          self.max_multi = solution[:max_multi].nil? ? nil : solution[:max_multi].object
        end
        unless solution[:min_repeat].nil? and solution[:max_repeat].nil?
          self.min_repeat = solution[:max_repeat].nil? ? 0 : solution[:min_repeat].object
          self.max_repeat = solution[:max_repeat].nil? ? nil : solution[:max_repeat].object
        end

        self.exact_value = solution[:exact_value]

        self.pattern_step = solution[:next]
        self.after = solution[:after]
        self.before = solution[:before]
        self.order = solution[:order]
        self.type = solution[:type]
      end

      def to_s
        state = case
                when !resolved?
                  "?"
                when accepting?
                  "Acpt"
                when rejecting?
                  "Rjct"
                end
        "<#{self.class.name.sub(/.*::/,'')} #{predicate}*M:#{min_multi}(<?#{available_count rescue "-"})-(#{accepting_count rescue "-"}<?)#{max_multi} R:#{min_repeat}-#{max_repeat}:#{step_count} #{state} >"
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
        Node.find_child_nodes(self)
      end
    end

    class ForwardEdge < Edge
      def self.path_direction
        Graph::Path.forward
      end

      def pattern_hash
        { :subject => graph_term, :predicate => predicate, :object => exact_value}
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
        { :subject => exact_value, :predicate => predicate, :object => graph_term }
      end

      def graph_node(statement)
        statement.subject
      end
    end

    class Node < MatchStep
      attr_accessor :statement #the RDF statement that got here from parent

      def self.find_child_nodes(edge)
        edge.graph.query(edge.pattern_hash).map do |statement|
          next if edge.stem.has_key?(statement)

          Node.new do |node|
            node.from(edge, statement)
          end
        end
      end

      def from(edge, statement)
        self.parent = edge

        self.pattern = edge.pattern
        self.graph = edge.graph

        self.stem = edge.stem
        self.repeats = edge.repeats.merge({edge.pattern_step => edge.step_count + 1})
        self.graph_term = edge.graph_node(statement)

        self.statement = statement

        self.pattern_step = edge.pattern_step
        self.after = edge.after
        self.before = edge.before
        self.order = edge.order
        self.type = edge.type
      end

      alias child_edges children

      def to_s
        state = case
                when !resolved?
                  "?"
                when accepting?
                  "Acpt"
                when rejecting?
                  "Rjct"
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

      def reject_value?
        unless before.nil? and after.nil?
          return true if not (before.nil? or before > graph_term)
          return true if not (after.nil? and after < graph_term)
        end

        unless type.nil?
          return true if graph_term.datatype != type
        end

        return false
      end

      def resolved?
        @resolved ||= accepting? or rejecting?
      end

      def accepting?
        @accepting ||=
          if excluded?
            false
          elsif children.nil?
            false
          elsif reject_value?
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
            elsif reject_value?
              true
            else
              child_edges.any? do |edge|
                edge.rejecting?
              end
            end
          end
      end

      def build_children
        ForwardEdge.find_child_edges(self) + ReverseEdge.find_child_edges(self)
      end
    end

    def initialize()
      @logging = false
      reset
    end

    attr_accessor :pattern, :logging
    attr_reader :completed_child

    def match(root, graph)
      reset
      setup(root, graph)
      search_iteration until complete?
      return Match.new(self)
    end

    def reset
      @search_queue = []
      @completed_child = nil
    end

    def setup(root, graph)
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
    end

    def pattern_root
      @pattern_root ||=
        begin
          roots = pattern.query(:predicate => ::RDF.type, :object => Graph::Path.Root).to_a
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
      log "Resolved:", matching
      @completed_child = matching
    end

    def search_iteration
      matching = next_matching_node
      unless matching.nil?
        matching.open
        if matching.children.empty?
          log "No match:", matching
        else
          log "Matches for:", matching
        end
        add_matching_nodes(matching.children)

        check_complete(matching)
      end
    end

    def next_matching_node
      @search_queue.pop #simple depth first
    end

    def add_matching_nodes(list)
      list.each do |node|
        log "  Adding step:", node
      end
      @search_queue += list
    end

    def log(*args)
      puts args.join(" ") if @logging
    end

    def resolved?
      false
    end

    def check_complete(matching)
      while matching.resolved?
        log "Checking:", matching
        matching.parent.notify_resolved(matching)
        matching = matching.parent
      end
    end
  end
end
