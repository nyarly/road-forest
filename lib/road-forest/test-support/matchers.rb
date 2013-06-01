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

    module MatcherMethods
      def match_query(&block)
        MatchesQuery.new(&block)
      end
    end
  end
end

RSpec::configure do |config|
  config.include RoadForest::Testing::MatcherMethods
end
