require 'roadforest/graph/normalization'

describe RoadForest::Graph::Normalization do
  include described_class

  describe "#normalize_term" do
    it "should resolve a curie" do
      normalize_term([:rf, "Impulse"]).to_s.should == "http://lrdesign.com/graph/roadforest#Impulse"
    end
  end

  describe "#normalize_resource" do
    it "should match http://test.com and http://test.com/" do
      normalize_resource("http://test.com").to_s.should == normalize_resource("http://test.com/").to_s
    end

    it "should match http://test.com:8888 and http://test.com:8888/" do
      normalize_resource("http://test.com:8888").to_s.should == "http://test.com:8888/"
    end

    it "should match http://localhost:8778 and http://localhost:8778/" do
      normalize_resource("http://localhost:8778").to_s.should == "http://localhost:8778/"
    end
  end

  describe "normalize_context" do
    it "should remove fragment part" do
      normalize_context("http://localhost:8778/place#fragment").to_s.should == "http://localhost:8778/place"
    end

    it "should remove the fragment from a frozen URL" do
      uri = ::RDF::URI.new("http://localhost:8778/place#fragment").freeze

      normalize_context(uri).to_s.should == "http://localhost:8778/place"
    end

    it "should remove the fragment from an array-wrapped frozen URL" do
      uri = ::RDF::URI.new("http://localhost:8778/place#fragment").freeze

      normalize_context([uri]).to_s.should == "http://localhost:8778/place"
    end
  end
end
