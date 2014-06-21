require 'roadforest/application/dispatcher'
require 'roadforest/interface/application'

describe RoadForest::Dispatcher do
  let :application do
    double(RoadForest::Application)
  end

  let :dispatcher do
    RoadForest::Dispatcher.new(application)
  end

  let :test_interface_class do
    Class.new(RoadForest::Interface::Application)
  end

  describe "with one RoadForest route" do
    before :each do
      dispatcher.add( :test, ["test"], :leaf, test_interface_class )
    end

    it "should be able to get an Interface class from a route" do

      dispatcher.route_for_name(:test).interface_class.should == test_interface_class
    end

    it "should iterate through routes" do
      routes = []
      dispatcher.each_route do |route|
        route.should be_a(RoadForest::Application::Route)
        routes << route
      end
      routes.length.should == 1
    end
  end
end
