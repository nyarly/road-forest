require 'rdf'
#require 'rdf/rdfa'
require 'road-forest/rdf/document'
require 'road-forest/rdf/graph-store'

describe RoadForest::RDF do
  let :source_rigor do
    RoadForest::RDF::SourceRigor.new.tap do |skept|
      skept.policy_list(:may_subject)
      skept.investigator_list(:null)
    end
  end

  let :graph_store do
    RoadForest::RDF::GraphStore.new do |handler|
      handler.source_rigor = source_rigor
    end
  end

  #merging graphs

  describe RoadForest::RDF::GraphStore do
    let :root_body do
      store = RoadForest::RDF::GraphStore.new
      step = RoadForest::RDF::GraphFocus.new("http://lrdesign.com/test-rdf", store, source_rigor)
      step[[:foaf, :givenname]] = "Lester"
      step[[:dc, :date]] = Time.now
      step = step.node_at([:dc, :related], "http://lrdesign.com/test-rdf/sub")
      step[[:dc, :date]] = Time.now

      store.graph_dump(:rdfa)
    end

    let :second_body do
      store = RoadForest::RDF::GraphStore.new
      step = RoadForest::RDF::GraphFocus.new("http://lrdesign.com/test-rdf", store, source_rigor)
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

    before :each do
      graph_store.insert_document(first_doc)
    end

    it "should transmit properties" do
      step = RoadForest::RDF::GraphFocus.new("http://lrdesign.com/test-rdf", graph_store, source_rigor)
      step[:dc, :date].should be_an_instance_of(Time)
    end

    it "should replace previous statements from same URL" do
      expect{
        graph_store.insert_document(second_doc)
      }.to change{
        RoadForest::RDF::GraphFocus.new("http://lrdesign.com/test-rdf", graph_store, source_rigor)[:foaf, :givenname]
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
      graph_store.add_statement(root, [:dc, :relation], main_subject)
      graph_store.add_statement(creator, [:foaf, :familyName], "Lester")
      graph_store.add_statement(creator, [:foaf, :givenname], "Judson")
      graph_store.add_statement(main_subject, [:dc, :creator], creator)
      graph_store.add_statement(main_subject, [:dc, :date], Time.now)
    end

    let :step do
      RoadForest::RDF::GraphFocus.new(main_subject, graph_store, source_rigor)
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

    it "should be able to add properties with []=", :pending => "Should GraphStores accept local writes?" do
      step[[:dc, :dateCopyrighted]] = Time.now #slightly ugly syntax
      step[:dc, :dateCopyrighted].should be_an_instance_of(Time)
      RDF::Query.new do |query|
        query.pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end.execute(graph_store).should_not be_empty
    end

    it "should be able to add properties with set", :pending => "Should GraphStores accept local writes?" do
      step.set(:dc, :dateCopyrighted, Time.now)
      step[:dc, :dateCopyrighted].should be_an_instance_of(Time)
      RDF::Query.new do |query|
        query.pattern [:subject, RDF::DC.dateCopyrighted, :value]
        store.execute(graph_store).should_not be_empty
      end
    end
  end
end
