module RoadForest
  module Testing
    class MatchesQuery
      def initialize(pattern = nil, &block)
        if pattern.nil? and block.nil?
          raise "Matches query (e.g. should match_query) created with no patterns: probably used a do block..."
        end
        pattern ||= []
        if Hash === pattern
          pattern = [pattern]
        end
        pattern = pattern.map do |item|
          ::RDF::Query::Pattern.from(item)
        end
        @query = ::RDF::Query.new(pattern, &block)
      end

      def matches?(actual)
        @actual = actual
        solutions = @query.execute(actual)
        not solutions.empty?
      end

      def failure_message_for_should
        "expected #{@query.patterns.inspect} to return solutions on \n#{@actual.dump(:nquads)}\n but didn't"
      end

      def failure_message_for_should_not
        "expected #{@query.patterns.inspect} not to return solutions on \n#{@actual.dump(:nquads)}\n but does"
      end
    end

    class ListEquivalence
      def initialize(expected)
        @expected = expected
      end

      def subtract(one, other)
        sorted = one.sort_by{|stmt| stmt.to_a}
        one.find_all do |expected_stmt|
          not other.any? do |actual_stmt|
            actual_stmt.eql? expected_stmt
          end
        end
      end

      def missing
        @missing ||= subtract(@expected, @actual)
      end

      def surplus
        @surplus ||= subtract(@actual, @expected)
      end

      def matches?(actual)
        @actual = actual
        missing.empty? and surplus.empty?
      end

      def failure_message_for_should
        "expected [\n  #{@actual.map(&:to_s).join("\n  ")}\n] " +
          "to have the same elements as [\n  #{@expected.map(&:to_s).join("\n  ")}\n]\n\n" +
          "missing: [\n  #{missing.map(&:to_s).join("\n  ")}\n]\n" +
          "surplus: [\n  #{surplus.map(&:to_s).join("\n  ")}]"
      end
    end

    class StatementsFromGraph
      def initialize(graph)
        @graph = graph
      end

      def that_match_query(query)
        @graph.query(query).to_a
      end
      alias that_match that_match_query
      alias that_match_pattern that_match_query
    end

    module HelperMethods
      def statements_from_graph(graph)
        StatementsFromGraph.new(graph)
      end
    end

    module MatcherMethods
      def match_query(pattern = nil, &block)
        MatchesQuery.new(pattern, &block)
      end

      def be_equivalent_to(list)
        ListEquivalence.new(list)
      end
    end
  end
end

RSpec::configure do |config|
  config.include RoadForest::Testing::MatcherMethods
  config.include RoadForest::Testing::HelperMethods
end
