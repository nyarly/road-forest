require 'roadforest/rdf/graph-focus'
require 'roadforest/rdf/source-rigor'
require 'roadforest/rdf/graph-store'
require 'roadforest/rdf/document'
require 'rdf/rdfa'

describe RoadForest::RDF::GraphFocus, "with UpdateManager" do
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
    RoadForest::RDF::GraphStore.new.tap do |graph|
      graph.insert_document(document)
    end
  end

  let :target_graph do
    ::RDF::Repository.new
  end

  let :source_rigor do
    ::RoadForest::RDF::SourceRigor.new.tap do |skept|
      skept.policy_list(:may_subject, :any)
      skept.investigator_list(:null)
    end
  end

  let :access do
    RoadForest::RDF::UpdateManager.new.tap do |access|
      access.source_graph = source_graph
      access.target_graph = target_graph
      access.rigor = source_rigor
    end
  end

  subject :updater do
    RoadForest::RDF::GraphFocus.new(access, context_node)
  end

  it "should make relevant prefixes available" do
    updater[[:rdf, :type]] = [:voc, :Thing]
    updater[[:voc, :a]] = 15

    updater.relevant_prefixes.keys.sort.should == ["rdf", "voc"]
  end

  it "should copy entire context when resource is written" do
    updater[Voc[:a]] = 17

    resource_graph = ::RDF::Graph.new(context_node, :data => target_graph)

    resource_graph.query(:object => RoadForest::RDF::Vocabulary::RF[:Impulse]).should be_empty
    resource_graph.query(simple_statement).should be_empty

    resource_graph.query(blank_node_statement).should_not be_empty
    resource_graph.query([context_node, Voc[:a], 17]).should_not be_empty
  end

  it "should copy entire context when blank node is written to" do
    updater[Voc[:b]][Voc[:c]] = "jagular" #they drop from trees

    resource_graph = ::RDF::Graph.new(context_node, :data => target_graph)

    resource_graph.query(blank_node_statement).should_not be_empty
    resource_graph.query(simple_statement).should_not be_empty
    resource_graph.query([nil, Voc[:c], "jagular", context_node]).should_not be_empty
  end

  it "should trigger (only one) Store query just by writing" do
    updater[Voc[:d]] = 14
    updater[Voc[:e]] = "fourteen"

    resource_graph = ::RDF::Graph.new(context_node, :data => target_graph)

    resource_graph.query(blank_node_statement).should_not be_empty
    resource_graph.query(simple_statement).should_not be_empty
    resource_graph.query([context_node, Voc[:d], 14]).should_not be_empty
    resource_graph.query([context_node, Voc[:e], "fourteen"]).should_not be_empty
  end

  it "should return statements that have been written" do
    updater[Voc[:a]] = 17
    updater[Voc[:a]].should == 17
  end

  it "should not copy contexts simply because they're read from" do
    updater[Voc[:a]].should == 7
    target_graph.should be_empty
  end

  it "should add a list to the target graph" do
    list_focus = updater.add_node(Voc[:list])
    nodes = []
    list_focus.as_list.append_node do |node|
      nodes << node
      node[Voc[:d]] = 107
    end

    list_focus.as_list.append_node do |node|
      nodes << node
      node[Voc[:d]] = 109
    end

    list_focus.as_list.append_node do |node|
      nodes << node
      node[Voc[:d]] = 113
    end

    resource_graph = ::RDF::Graph.new(context_node, :data => target_graph)

    list = ::RDF::List.new(list_focus.subject, target_graph)

    list[0].should == nodes[0].subject
    list[1].should == nodes[1].subject
    list[2].should == nodes[2].subject
    resource_graph.query([nodes[0].subject, Voc[:d], 107]).should_not be_empty
    resource_graph.query([nodes[1].subject, Voc[:d], 109]).should_not be_empty
    resource_graph.query([nodes[2].subject, Voc[:d], 113]).should_not be_empty
  end
end
