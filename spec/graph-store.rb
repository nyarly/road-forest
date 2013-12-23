require 'rdf'
require 'rdf/rdfa'
require 'roadforest/rdf/document'
require 'roadforest/rdf/graph-store'
require 'roadforest/rdf/graph-focus'
require 'roadforest/rdf/source-rigor'

describe RoadForest::RDF do
  let :source_rigor do
    RoadForest::RDF::SourceRigor.new.tap do |skept|
      skept.policy_list(:may_subject)
      skept.investigator_list(:null)
    end
  end

  let :graph_store do
    RoadForest::RDF::GraphStore.new
  end

  #merging graphs

  describe RoadForest::RDF::GraphStore do
    let :root_body do
      store = RoadForest::RDF::GraphStore.new
      access = RoadForest::RDF::WriteManager.new
      access.source_graph = store
      access.rigor = source_rigor
      step = RoadForest::RDF::GraphFocus.new(access, "http://lrdesign.com/test-rdf")

      step[[:foaf, :givenname]] = "Lester"
      step[[:dc, :date]] = Time.now
      step = step.node_at([:dc, :relation], "http://lrdesign.com/test-rdf/sub")
      step[[:dc, :date]] = Time.now

      store.graph_dump(:rdfa)
    end

    let :second_body do
      store = RoadForest::RDF::GraphStore.new
      access = RoadForest::RDF::WriteManager.new
      access.source_graph = store
      access.rigor = source_rigor
      step = RoadForest::RDF::GraphFocus.new(access, "http://lrdesign.com/test-rdf")

      step[[:foaf, :givenname]] = "Foster"
      step[[:dc, :date]] = Time.now

      store.graph_dump(:rdfa)
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

    let :step do
      access = RoadForest::RDF::WriteManager.new
      access.source_graph = graph_store
      access.rigor = source_rigor
      RoadForest::RDF::GraphFocus.new(access, "http://lrdesign.com/test-rdf")
    end

    before :each do
      graph_store.insert_document(first_doc)
    end

    it "should transmit properties" do
      step[:dc, :date].should be_an_instance_of(Time)
    end

    it "should replace previous statements from same URL" do
      expect{
        graph_store.insert_document(second_doc)
      }.to change{
        step[:foaf, :givenname]
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

    let :graph_store do
      RDF::Graph.new
    end

    before :each do
      graph_store.insert([root, ::RDF::DC.relation, main_subject])
      graph_store.insert([creator, ::RDF::FOAF.familyName, "Lester"])
      graph_store.insert([creator, ::RDF::FOAF.givenname, "Judson"])
      graph_store.insert([main_subject, ::RDF::DC.creator, creator])
      graph_store.insert([main_subject, ::RDF::DC.date, Time.now])
    end

    let :access do
      RoadForest::RDF::WriteManager.new.tap do |access|
        access.rigor = source_rigor
        access.source_graph = graph_store
      end
    end

    let :step do
      RoadForest::RDF::GraphFocus.new(access, main_subject)
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
      RDF::Query.new do |query|
        query.pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end.execute(graph_store).should_not be_empty
    end

    it "should be able to add properties with set" do
      step.set(:dc, :dateCopyrighted, Time.now)
      step[:dc, :dateCopyrighted].should be_an_instance_of(Time)
      RDF::Query.new do |query|
        query.pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end.execute(graph_store).should_not be_empty
    end
  end
end
