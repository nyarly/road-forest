require 'road-forest/test-support/matchers'
require 'road-forest/rdf/graph-copier'

#Leaving notes since being interrupted
#
#GC needs to tessellate the graph in the same way that Parceller should -
#probably should make sure that works first. Basically same resource should ==
#same subgraph copied, since otherwise client omission of a property isn't
#distinguishable from the intent to delete it. Only copy once so that you don't
#overwrite client changes.
#
#Also: "single put" involves a whole extra level of server code to accept the
#put, parcel it out, confirm IMS headers across everyone... so that's a v2
#feature

describe RoadForest::RDF::GraphCopier, :pending => "review of API" do
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
      [start_subject, TestVoc[:other], other_subject]
    ]
  end

  let :other_statements do
    [
      [other_subject, TestVoc[:a], 13]
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

  let :document do
    RoadForest::RDF::Document.new.tap do |doc|
      doc.source =
      doc.body_string = source_graph.dump(:rdfa)
    end
  end

  let :copier do
    RoadForest::RDF::GraphCopier.new.tap do |copier|
      copier.source_graph = source_graph
      copier.subject = start_subject
    end
  end

  it "reads the notes above, unless it wants the hose again" do
    fail "shoulda read the notes"
  end

  it "should have a target graph" do
    copier.target_graph.should be_an_instance_of(::RDF::Graph)
  end

  it "should have statements about starting subject" do
    statements_from_graph(copier.target_graph).that_match_query(:subject => start_subject).should be_equivalent_to(starting_statements)
  end

  it "should not have statements about other subject" do
    copier.target_graph.query(:subject => other_subject).to_a.should be_empty
  end

  it "should get statements about other subject" do
    copier[[:testvoc, :other]]

    statements_from_graph(copier.target_graph).that_match_query(:subject => other_subject).should be_equivalent_to(other_statements)
  end
end
