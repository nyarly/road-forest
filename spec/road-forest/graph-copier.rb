require 'road-forest/rdf/graph-copier'

describe RoadForest::RDF::GraphCopier do
  class TestVoc < ::RDF::Vocabulary("http://test.com/");end

  let :start_subject do
    RDF::Resource.new
  end

  let :other_subject do
    RDF::Resource.new
  end

  let :starting_statements do
    [
      [start_subject, TestVoc[:a], 7],
      [start_subject, TestVoc[:other], other_subject]
    ]
  end

  let :other_statements do
    [
      [other_subject, TestVoc[:a], 7]
    ]
  end

  let :source_graph do
    ::RDF::Graph.new.tap do |graph|
      starting_statements.each do |stmt|
        graph << stmt
      end

      other_statements.each do |stmt|
        graph << stmt
      end
    end
  end

  let :copier do
    RoadForest::RDF::GraphCopier.new.tap do |copier|
      copier.source_graph = source_graph
      copier.subject = start_subject
    end
  end

  it "should have a target graph" do
    copier.target_graph.should be_an_instance_of(::RDF::Graph)
  end

  it "should have statements about starting subject" do
    statements_from_graph(copier.target_graph).that_match_query(:subject => starting_subject).should be_equivalent_to(starting_statements)
  end

  it "should not have statements about other subject" do
    copier.target_graph.query(:subject => other_subject).to_a.should be_empty
  end

  it "should get statements about other subject" do
    copier[[:test, :other]]

    statements_from_graph(copier.target_graph).that_match_query(:subject => other_subject).should be_equivalent_to(other_statements)
  end
end
