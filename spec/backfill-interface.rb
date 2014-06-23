require 'roadforest/application/dispatcher'
require 'roadforest/interface/application'
require 'roadforest/interface/utility/backfill'
require 'roadforest/application/services-host'

describe RoadForest::Utility::Backfill do
  let :application do
    double(RoadForest::Application)
  end

  let :dispatcher do
    RoadForest::Dispatcher.new(application)
  end

  let :test_interface_class do
    Class.new(RoadForest::Interface::RDF) do
      extend RoadForest::Graph::Helpers::Payloads

      payload_for_update do |focus|
        filename = focus.add_node([:path, :forward])
        filename[[:path, :predicate]] = "http://sillyvocab.com/a"
      end

      payload_for_create do |focus|
        filename = focus.add_node([:path, :forward])
        filename[[:path, :predicate]] = "http://sillyvocab.com/a"
      end
    end
  end

  before :each do
    dispatcher.add( :test, ["test"], :leaf, test_interface_class )
    dispatcher.add( :payload, ["payloads"], :read_only, RoadForest::Utility::Backfill )
  end

  let :services do
    Class.new(RoadForest::Application::ServicesHost) do

    end.new.tap do |host|
      host.root_url = "http://example.com"
      host.router = dispatcher
    end
  end

  let :backfill do
    RoadForest::Utility::Backfill.new(:payload, {}, dispatcher.path_provider(:payload), services)
  end

  it "should have payloads that point to backfill" do
    test_interface_class.new(:test, {}, dispatcher.path_provider(:test), services).update_payload.root.should == "http://example.com/payloads#test-update"
  end

  require 'rdf/turtle'
  it "should build a useful graph" do
    backfill.retrieve.should be_equivalent_graph(<<-EOT)
      @base <http://example.com/payloads> .
      @prefix path: <http://judsonlester.info/rdf-vocab/path#> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      <#test-create> path:forward [ path:predicate "http://sillyvocab.com/a"] .

      <#test-update> path:forward [ path:predicate "http://sillyvocab.com/a"] .
    EOT
  end
end
