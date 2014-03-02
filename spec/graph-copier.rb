require 'roadforest/test-support/matchers'
require 'roadforest/graph/graph-copier'

describe RoadForest::Graph::GraphFocus, "with a CopyManager" do
  class TestVoc < ::RDF::Vocabulary("http://test.com/");end

  let :start_subject do
    RDF::Node.new
  end

  let :other_subject do
    RDF::Node.new
  end

  let :starting_statements do
    [
      [start_subject, TestVoc[:a], 7],
      [start_subject, TestVoc[:other], other_subject],
      [other_subject, TestVoc[:a], 13]
    ]
  end

  let :source_graph do
    ::RDF::Graph.new.tap do |graph|
      starting_statements.each do |stmt|
        graph << stmt
      end
    end
  end

  let :target_graph do
    ::RDF::Graph.new
  end

  let :access do
    RoadForest::Graph::CopyManager.new.tap do |access|
      access.source_graph = source_graph
      access.target_graph = target_graph
    end
  end

  let :copier do
    RoadForest::Graph::GraphFocus.new(access, start_subject)
  end

  #copier needs URL accessor



  it "should not copy statements without action" do
    target_graph.should_not match_query(:subject => start_subject)
  end

  it "should copy statements that are queried" do
    copier[[:testvoc, :other]]

    statements_from_graph(target_graph).that_match_query(:predicate => TestVoc[:other]).should(
      be_equivalent_to(statements_from_graph(source_graph).that_match_query(:predicate => TestVoc[:other]))
    )
    target_graph.should_not match_query(:predicate => TestVoc[:a])
  end

  it "should not double copy statements that are queried twice" do
    copier[[:testvoc, :other]]
    copier[[:testvoc, :other]]

    statements_from_graph(target_graph).that_match_query(:predicate => TestVoc[:other]).should(
      be_equivalent_to(statements_from_graph(source_graph).that_match_query(:predicate => TestVoc[:other]))
    )
  end
end
