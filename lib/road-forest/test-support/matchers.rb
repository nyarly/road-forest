module RoadForest
  module Testing
    class MatchesQuery
      def initialize(&block)
        @query = ::RDF::Query.new(&block)
      end

      def matches?(actual)
        @actual = actual
        solutions = @query.execute(actual)
        not solutions.empty?
      end

      def failure_message_for_should
        "expected #{@query.inspect} to return solutions on #{@actual.inspect}, but didn't"
      end
    end

    class ListEquivalence
      def initialize(expected)
        @expected = expected
      end

      def matches?(actual)
        @actual = actual
        @actual_extra = @actual - @expected
        @expected_extra = @expected - @actual
        @actual_extra.empty? and @expected_extra.empty?
      end

      def failure_message_for_should
        "expected #{@actual.inspect} to have the same elements as #{@expected.inspect}"
      end
    end

    class StatementsFromGraph
      def initialize(graph)
        @graph = graph
      end

      def that_match_query(query)
        @graph.query(query).to_a
      end
    end

    module HelperMethods
      def statements_from_graph(graph)
        StatementsFromGraph.new(graph)
      end
    end

    module MatcherMethods
      def match_query(&block)
        MatchesQuery.new(&block)
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
