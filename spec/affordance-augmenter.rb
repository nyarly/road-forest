require 'roadforest/affordance/augmenter'
require 'roadforest/model'
require 'roadforest/application'

describe RoadForest::Affordance::Augmenter do
  let :test_model do
    Class.new(RoadForest::RDFModel)
  end

  let :other_test_model do
    Class.new(RoadForest::RDFModel)
  end

  Af = RoadForest::RDF::Af

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
      router.add :test, ["a"], :parent, test_model
      router.add :nest, ["a", "b", :id], :leaf, other_test_model
    end
  end

  let :augmenter do
    described_class.new.tap do |augmenter|
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
