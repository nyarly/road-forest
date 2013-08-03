require 'road-forest/http/media-type'
describe RoadForest::HTTP::MediaType do
  let :accepted_list do
    RoadForest::HTTP::MediaTypeList.build("text/*;q=0.3, text/html;q=0.7, text/html;level=1, text/html;level=2;q=0.4, */*;q=0.5")
  end

  let :provided_list do
    RoadForest::HTTP::MediaTypeList.build("text/html;q=0.9;rdfa=true, application/json+ld;q=0.4")
  end

  it "should find best match" do
    accepted_list.best_match_from(provided_list).should =~ "text/html"
  end
end
