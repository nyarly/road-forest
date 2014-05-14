require 'rdf/isomorphic'
require 'rspec/matchers'
require 'nokogiri'

class RDF::Repository
  include RDF::Isomorphic
end

class RDF::Graph
  include RDF::Isomorphic
end

module RoadForest
  module Testing
    module HelperMethods
      def statements_from_graph(graph)
        StatementsFromGraph.new(graph)
      end

      def normalize(graph)
        case graph
        when RDF::Queryable then graph
        when IO, StringIO
          RDF::Graph.new.load(graph, :base_uri => @info.about)
        else
          # Figure out which parser to use
          g = RDF::Graph.new
          reader_class = detect_format(graph)
          reader_class.new(graph, :base_uri => @info.about).each {|s| g << s}
          g
        end
      end
    end

    class BeEquivalentGraph
      include HelperMethods
      Info = Struct.new(:about, :num, :trace, :compare, :inputDocument, :outputDocument, :expectedResults, :format, :title)

      def initialize(expected, info)
        @expected = normalize(expected)

        @info =
          if info.respond_to?(:about)
            info
          elsif info.is_a?(Hash)
            identifier = expected.is_a?(RDF::Graph) ? expected.context : info[:about]
            trace = info[:trace]
            trace = trace.join("\n") if trace.is_a?(Array)
            i = Info.new(identifier, "0000", trace, info[:compare])
            i.format = info[:format]
            i
          else
            Info.new(expected.is_a?(RDF::Graph) ? expected.context : info, "0000", info.to_s)
          end

        @info.format ||= :ttl
      end
      attr_reader :expected, :info

      def matches?(actual)
        @actual = normalize(actual)
        @actual.isomorphic_with?(@expected)# rescue false
      end

      def dump_graph(graph)
        graph.dump(@info.format, :standard_prefixes => true)
      rescue
        begin
          graph.dump(:nquads, :standard_prefixes => true)
        rescue
          graph.inspect
        end
      end

      def description
        "be equivalent to an expected graph" #graphs tend to be too long to use
      end

      def failure_message_for_should
        info = @info.respond_to?(:about) ? @info.about : @info.inspect
        if @expected.is_a?(RDF::Graph) && @actual.size != @expected.size
          "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
        elsif @expected.is_a?(Array) && @actual.size != @expected.length
          "Graph entry count differs:\nexpected: #{@expected.length}\nactual:   #{@actual.size}"
        else
          "Graph differs"
        end +
          "\n#{info + "\n" unless info.to_s.empty?}" +
          (@info.inputDocument ? "Input file: #{@info.inputDocument}\n" : "") +
        (@info.outputDocument ? "Output file: #{@info.outputDocument}\n" : "") +
        "\nExpected:\n#{dump_graph(@expected)}" +
          "\nResults:\n#{dump_graph(@actual)}" +
          (@info.trace ? "\nDebug:\n#{@info.trace}" : "")
      end
    end

    class HaveXpath
      def initialize(xpath, value, trace)
        @xpath, @value, @trace = xpath, value, trace
      end
      attr_reader :xpath, :value, :trace

      def matches?(actual)
        @doc = Nokogiri::HTML.parse(actual)
        @namespaces = @doc.namespaces.merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
        found = @doc.root.at_xpath(xpath, @namespaces)
        case value
        when false
          found.nil?
        when true
          !found.nil?
        when Array
          found.to_s.split(" ").include?(*value)
        when Regexp
          found.to_s =~ value
        else
          found.to_s == value
        end
      end

      def failure_message_for_should(actual)
        trace ||= debug
        msg =
          case value
          when true
            "expected that #{xpath.inspect} would be present\nwas:\n  #{found.inspect}\n"
          when false
            "expected that #{xpath.inspect} would be absent\nwas:\n  #{found.inspect}\n"
          else
            "expected that #{xpath.inspect} would be\n  #{value.inspect}\nwas:\n  #{found.inspect}\n"
          end
        msg += "in:\n" + actual.to_s
        msg +=  "\nDebug:#{trace.join("\n")}" if trace
        msg
      end

      def failure_message_for_should_not(actual)
        trace ||= debug
        msg = "expected that #{xpath.inspect} would not be #{value.inspect} in:\n" + actual.to_s
        msg +=  "\nDebug:#{trace.join("\n")}" if trace
        msg
      end
    end

    class Produces
      def initialize(expected, info)
        @expected, @info = expected, info
      end
      attr_reader :expected, :info

      def matches?(actual)
        actual == expected
      end

      def failure_message_for_should(actual)
        "Expected: #{expected.inspect}\n" +
        "Actual  : #{actual.inspect}\n" +
        "Processing results:\n#{info.join("\n")}"
      end
    end

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

      def indent(string)
        string.split("\n").map{|line| "  " + line}.join("\n")
      end

      def failure_message_for_should
        require 'pp'
        "expected: \n#{indent(@query.patterns.pretty_inspect)} \nto return solutions on \n\n#{indent(@actual.dump(:nquads))}\n but didn't"
      end

      def failure_message_for_should_not
        require 'pp'
        "expected: \n#{indent(@query.patterns.pretty_inspect)} \nnot to return solutions on \n\n#{indent(@actual.dump(:nquads))}\n but does" end
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

    module MatcherMethods
      def produce(expected, info)
        Produces.new(expected, info)
      end

      def have_xpath(xpath, value = true, trace = nil)
        HaveXpath.new(xpath, value, trace || debug)
      end

      def match_query(pattern = nil, &block)
        MatchesQuery.new(pattern, &block)
      end

      def be_equivalent_graph(graph, info = nil)
        BeEquivalentGraph.new(graph, info)
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
