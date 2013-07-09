require 'road-forest/rdf/update-focus'
require 'road-forest/rdf/document'
require 'rdf/rdfa'

describe RoadForest::RDF::UpdateFocus do
  class Voc < ::RDF::Vocabulary("http:/pred.org/"); end

  let :context_node do
    ::RDF::URI.intern("http://subject.org/a")
  end

  let :blank_node do
    ::RDF::Node.new
  end

  let :simple_statement do
    ::RDF::Statement.from [ context_node, Voc[:a], 7 ]
  end

  let :blank_node_statement do
    ::RDF::Statement.from [ context_node, Voc[:b], blank_node ]
  end

  let :context_statements do
    [
      simple_statement,
      blank_node_statement
    ]
  end

  let :body_graph do
    ::RDF::Graph.new.tap do |graph|
      context_statements.each do |stmt|
        graph << stmt
      end
    end
  end

  let :document do
    RoadForest::RDF::Document.new.tap do |doc|
      doc.source = context_node.to_s
      doc.body_string = body_graph.dump(:rdfa)
    end
  end

  let :source_graph do
    RoadForest::RDF::GraphManager.new.tap do |graph|
      graph.insert_document(document)
    end
  end

  let :target_graph do
    ::RDF::Repository.new
  end

  let :source_skepticism do
    ::RoadForest::RDF::SourceSkepticism.new.tap do |skept|
      skept.policy_list(:may_subject, :any)
      skept.investigator_list(:null)
    end
  end

  subject :updater do
    RoadForest::RDF::UpdateFocus.new.tap do |updater|
      updater.source_graph = source_graph
      updater.target_graph = target_graph
      updater.subject = context_node
      updater.source_skepticism = source_skepticism
    end
  end

  it "should copy entire context when resource is written" do
    updater[Voc[:a]] = 17

    resource_graph = ::RDF::Graph.new(context_node, :data => target_graph)

    resource_graph.query(blank_node_statement).should_not be_empty
    resource_graph.query([context_node, Voc[:a], 17]).should_not be_empty
    resource_graph.query(simple_statement).should be_empty
  end

  it "should copy entire context when blank node is written to" do
    updater[Voc[:b]][Voc[:c]] = "jagular" #they drop from trees

    resource_graph = ::RDF::Graph.new(context_node, :data => target_graph)

    resource_graph.query(blank_node_statement).should_not be_empty
    resource_graph.query(simple_statement).should_not be_empty
    resource_graph.query([blank_node, Voc[:c], "jagular"]).should_not be_empty
  end

  it "should trigger a Manager query just by writing"

  it "should return statements that have been written" do
    updater[Voc[:a]] = 17
    updater[Voc[:a]].should == 17
  end

  it "should not copy contexts simply because they're read from" do
    updater[Voc[:a]].should == 7
    target_graph.should be_empty
  end
end
