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

  let :voc do
    ::RDF::Vocabulary("http://example.com")
  end

  let :test_interface_class do
    Class.new(RoadForest::Interface::RDF) do
      def self.backfill_payload(domain, type, root)
        start_focus(nil, root) do |focus|
          filename = focus.add_node([:path, :forward])
          filename[[:path, :predicate]] = voc[:a]
        end
      end
    end
  end

  before :each do
    dispatcher.add( :test, ["test"], :leaf, test_interface_class )
    dispatcher.add( :payload, ["payloads"], :read_only, RoadForest::Utility::Backfill )
  end

  let :services do
    RoadForest::Application::ServicesHost.new
  end

  let :backfill do
    RoadForest::Utility::Backfill.new(:payload, {}, dispatcher, services)
  end

  it "should build a useful graph", :pending => "refactor 6-21-14" do
    backfill.retrieve.should be_equivalent_to("x:thing is rdf:Thing .")
  end
end
