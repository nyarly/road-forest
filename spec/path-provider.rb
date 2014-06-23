require 'roadforest/application/dispatcher'
require 'roadforest/application/path-provider'
require 'roadforest/interface/application'

describe RoadForest::PathProvider do
  let :application do
    double(RoadForest::Application)
  end

  let :route_name do
    :test
  end

  let :test_interface_class do
    Class.new(RoadForest::Interface::Application)
  end

  let :router do
    RoadForest::Dispatcher.new(application).tap do |router|
      router.add( :test, ["test"], :leaf, test_interface_class )
    end
  end

  let :provider do
    RoadForest::PathProvider.new(route_name, router)
  end

  it "should provide route to test interface" do
    provider.path_for(:test, {}).should == "/test"
  end
end
