require 'road-forest/rdf'
require 'road-forest/rdf/document'
require 'rdf/rdfa'

require 'webmachine/application'
require 'road-forest/resource/rdf-handlers'

describe RoadForest::RDF do
  let :graph_manager do
    RoadForest::RDF::GraphManager.new do |handler|
      handler.policy_list(:may_subject)
      handler.investigators = [RoadForest::RDF::NullInvestigator.new]
    end
  end

  #merging graphs

  describe RoadForest::RDF::GraphManager do
    let :root_body do
      manager = RoadForest::RDF::GraphManager.new
      step = manager.start("http://lrdesign.com/test-rdf")
      step[[:foaf, :givenname]] = "Lester"
      step[[:dc, :date]] = Time.now
      step = step.node_at([:dc, :related], "http://lrdesign.com/test-rdf/sub")
      step[[:dc, :date]] = Time.now

      manager.graph_dump(:rdfa)
    end

    let :second_body do
      manager = RoadForest::RDF::GraphManager.new
      step = manager.start("http://lrdesign.com/test-rdf")
      step[[:foaf, :givenname]] = "Foster"
      step[[:dc, :date]] = Time.now

      manager.graph_dump(:rdfa)
    end

    let :first_doc do
      RoadForest::RDF::Document.new.tap do |doc|
        doc.source = "http://lrdesign.com/test-rdf"
        doc.body_string = root_body
      end
    end

    let :second_doc do
      RoadForest::RDF::Document.new.tap do |doc|
        doc.source = "http://lrdesign.com/test-rdf"
        doc.body_string = second_body
      end
    end

    before :each do
      graph_manager.insert_document(first_doc)
    end

    it "should transmit properties" do
      step = graph_manager.start("http://lrdesign.com/test-rdf")
      step[:dc, :date].should be_an_instance_of(Time)
    end

    it "should replace previous statements from same URL" do
      expect{
        graph_manager.insert_document(second_doc)
      }.to change{
        graph_manager.start("http://lrdesign.com/test-rdf")[:foaf, :givenname]
      }
    end
  end

  describe RoadForest::RDF::GraphFocus do
    let :main_subject do
      RDF::URI.new("http://test.com/main")
    end

    let :creator do
      RDF::Node.new
    end

    let :root do
      RDF::Node.new
    end

    before :each do
      graph_manager.add_statement(root, [:dc, :relation], main_subject)
      graph_manager.add_statement(creator, [:foaf, :familyName], "Lester")
      graph_manager.add_statement(creator, [:foaf, :givenname], "Judson")
      graph_manager.add_statement(main_subject, [:dc, :creator], creator)
      graph_manager.add_statement(main_subject, [:dc, :date], Time.now)
    end

    let :step do
      graph_manager.start(main_subject)
    end

    it "should enumerate forward properties" do
      step.forward_properties.should include([:dc, :creator])
      step.forward_properties.should include([:dc, :date])
      step.forward_properties.should_not include([:foaf, :familyName])
      step.forward_properties.should_not include([:dc, :relation])
    end

    it "should get values for properties" do
      step.get(:dc, :creator).rdf.should == creator
      step.get(:dc, :date).should be_an_instance_of(Time)
      step[:dc, :date].should be_an_instance_of(Time)
      step[[:dc, :date]].should be_an_instance_of(Time)
    end

    it "should enumerate reverse properties" do
      step.reverse_properties.should include([:dc, :relation])
      step.reverse_properties.should_not include([:dc, :creator])
    end

    it "should get values for inbound properties" do
      step.rev(:dc, :relation).rdf.should == root
    end

    it "should walk forward to properties" do
      step[:dc,:creator][:foaf,:givenname].should == "Judson"
    end

    it "should be able to add properties with []=" do
      step[[:dc, :dateCopyrighted]] = Time.now #slightly ugly syntax
      step[:dc, :dateCopyrighted].should be_an_instance_of(Time)
      graph_manager.query(RDF::Query.new do |query|
        query.pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end).should_not be_empty
    end

    it "should be able to add properties with set" do
      step.set(:dc, :dateCopyrighted, Time.now)
      step[:dc, :dateCopyrighted].should be_an_instance_of(Time)
      graph_manager.query(RDF::Query.new do |query|
        query.pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end).should_not be_empty
    end
  end

  #self context available?

  #Statement Conflict:
  #merge blank nodes
  #missing property
  #  no auth statements
  #  old? auth statements
  #conflicting properties
  #non-authoritative statements
  #strategy for gets
  #
  #Still undesigned:
  #  Changes? (Update RDF, and PUT/POST/DELETE?
  #    or
  #  use forms directly, update #  based on response)
end
