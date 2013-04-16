require 'atst'
require 'atst/test-web-client'

describe ATST do
  let :walker do
    ATST::Walker.new
  end

  #merging graphs

  describe ATST::Walker do
    let :root_body do
      walker = ATST::Walker.new
      step = walker.start_walk("http://lrdesign.com/test-rdf")
      step[[:foaf, :givenname]] = "Lester"
      step[[:dc, :date]] = Time.now
      step = step.node_at([:dc, :related], "http://lrdesign.com/test-rdf/sub")
      step[[:dc, :date]] = Time.now

      walker.graph_dump(:rdfa)
    end

    let :second_body do
      walker = ATST::Walker.new
      step = walker.start_walk("http://lrdesign.com/test-rdf")
      step[[:foaf, :givenname]] = "Foster"
      step[[:dc, :date]] = Time.now

      walker.graph_dump(:rdfa)
    end

    let :test_client do
      client = ATST::TestWebClient.new
      client.add_response(%r{\Ahttp://lrdesign.com/test-rdf/?\Z}) do |builder|
        builder.body = root_body
      end
      client
    end

    before :each do
      walker.http_client = test_client
      walker.get("http://lrdesign.com/test-rdf/")
    end

    it "should transmit properties" do
      step = walker.start_walk("http://lrdesign.com/test-rdf")
      step[:dc, :date].should be_an_instance_of(Time)
    end

    it "should replace previous statements from same URL" do
      expect{
        test_client.add_response(%r{\Ahttp://lrdesign.com/test-rdf/?\Z}) do |builder|
          builder.body = second_body
        end
        walker.get("http://lrdesign.com/test-rdf/")
      }.to change{
        step = walker.start_walk("http://lrdesign.com/test-rdf")
        step[:foaf, :givenname]
      }
    end
  end

  describe ATST::Step do
    let :main_subject do
      RDF::Node.new(:main)
    end

    let :creator do
      RDF::Node.new
    end

    let :root do
      RDF::Node.new
    end

    before :each do
      walker.add_statement(root, [:dc, :relation], main_subject)
      walker.add_statement(creator, [:foaf, :familyName], "Lester")
      walker.add_statement(creator, [:foaf, :givenname], "Judson")
      walker.add_statement(main_subject, [:dc, :creator], creator)
      walker.add_statement(main_subject, [:dc, :date], Time.now)
    end

    let :step do
      walker.start_walk(main_subject)
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
      step.walker.query do
        pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end.should_not be_empty
    end

    it "should be able to add properties with set" do
      step.set(:dc, :dateCopyrighted, Time.now)
      step[:dc, :dateCopyrighted].should be_an_instance_of(Time)
      step.walker.query do
        pattern [:subject, RDF::DC.dateCopyrighted, :value]
      end.should_not be_empty
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
