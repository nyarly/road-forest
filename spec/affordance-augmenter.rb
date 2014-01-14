require 'roadforest/affordance/augmenter'
require 'roadforest/model'
require 'roadforest/application'

describe RoadForest::Affordance::Augmenter do
  class TestModel < RoadForest::RDFModel
  end

  class EX < RDF::Vocabulary("http://example/"); end

  let :service_host do
    double("ServiceHost")
  end

  let :application do
    double("RoadForest::Application").tap do |app|
      app.stub(:services).and_return(service_host)
    end
  end

  let :router do
    RoadForest::Dispatcher.new(application).tap do |router|
      router.add :test, ["a"], :parent, TestModel
    end
  end

  let :augmenter do
    described_class.new.tap do |augmenter|
      augmenter.router = router
    end
  end

  subject :augemented_graph do
    augmenter.augment(graph)
  end

  describe "simple updateable resource" do
    let :graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, "foo"]
      end
    end

    it "should add Update affordance" do
      subject.should match_query do
        pattern [:node, RDF.type, Af.Update]
        pattern [:node, Af.target, EX.a]
      end
    end
  end
end
