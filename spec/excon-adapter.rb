require 'roadforest/http/adapters/excon'

describe RoadForest::HTTP::ExconAdapter do
  let :adapter do
    RoadForest::HTTP::ExconAdapter.new("http://test-site.com").tap do |adapter|
      adapter.connection_defaults[:mock] = true
    end
  end

  before :each do
    Excon.stub do
      {
        :body => "Hello!"
      }
    end
  end

  after :each do
    Excon.stubs.clear
  end

  describe "responses to GET requests" do
    let :request do
      RoadForest::HTTP::Request.new("GET", "http://test-site.com/test")
    end

    subject :response do
      adapter.do_request(request)
    end

    its(:status){ should == 200 }
    its(:body_string){ should == "Hello!" }
  end
end
