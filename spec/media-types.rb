require 'roadforest/content-handling/media-type'

describe RoadForest::ContentHandling::MediaType do
  let :type_string do
    "text/html;q=0.42;rdfa;sublevel=3"
  end

  let :type do
    RoadForest::ContentHandling::MediaType.parse(type_string)
  end

  it "should parse accept_params" do
    type.params.should_not have_key(:q)
    type.quality.should == 0.42
    type.params.should have_key("rdfa")
    type.params.should have_key("sublevel")
    type.params["sublevel"].should == "3"
  end

  it "should produce a matching accept header" do
    type.accept_header.should == type_string
  end

  it "should produce a correct content-type header" do
    type.content_type_header.should == "text/html;rdfa;sublevel=3"
  end
end

describe RoadForest::ContentHandling::MediaTypeList do
  let :accepted_list do
    RoadForest::ContentHandling::MediaTypeList.build("text/*;q=0.3, text/html;q=0.7, text/html;level=1, text/html;q=0.4;level=2, */*;q=0.5")
  end

  let :provided_list do
    RoadForest::ContentHandling::MediaTypeList.build("text/html;q=0.9;rdfa, application/json+ld;q=0.4")
  end

  it "should find best match" do
    accepted_list.best_match_from(provided_list).should =~ "text/html"
  end
end
