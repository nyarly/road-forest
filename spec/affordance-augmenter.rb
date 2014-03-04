require 'roadforest/augment/affordance'
require 'roadforest/interfaces'
require 'roadforest/application'

describe RoadForest::Augment::Affordance do
  let :test_interface do
    Class.new(RoadForest::Interface::RDF)
  end

  let :other_test_interface do
    Class.new(RoadForest::Interface::RDF)
  end

  Af = RoadForest::Graph::Af

  class EX < RDF::Vocabulary("http://example.com/"); end

  let :service_host do
    RoadForest::Application::ServicesHost.new
  end

  let :content_engine do
    RoadForest::ContentHandling.rdf_engine
  end

  let :application do
    double("RoadForest::Application").tap do |app|
      app.stub(:services).and_return(service_host)
      app.stub(:default_content_engine).and_return(content_engine)
    end
  end

  let :router do
    RoadForest::Dispatcher.new(application).tap do |router|
      router.add :test, ["a"], :parent, test_interface
      router.add :nest, ["a", "b", :id], :leaf, other_test_interface
    end
  end

  let :augmenter do
    RoadForest::Augment::Augmenter.new.tap do |augmenter|
      augmenter.router = router
      augmenter.canonical_uri = Addressable::URI.parse("http://example.com/a")
    end
  end

  subject :augmented_graph do
    augmenter.augment(graph)
  end

  describe "simple updateable resource" do
    let :graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, EX["a/b/1"]]
      end
    end

    it "should add Update affordance" do
      subject.should match_query {
        pattern [:node, RDF.type, Af.Update]
        pattern [:node, Af.target, EX.a]
      }
    end

    it "should add Create affordance" do
      subject.should match_query {
        pattern [:node, RDF.type, Af.Create]
        pattern [:node, Af.target, EX.a]
      }
    end

    it "should add Delete affordance"
    it "should add Navigable affordance to child"
  end
end
