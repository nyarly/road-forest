require 'roadforest/graph/normalization'

describe RoadForest::Graph::Normalization do
  include described_class

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
