require 'roadforest-server'
require 'roadforest/graph/nav-affordance-builder'

describe RoadForest::Graph::NavAffordanceBuilder do
  let :services do
    RoadForest::Application::ServicesHost.new.tap do |host|
      host.root_url = "http://example.com"
    end
  end

  let :dest_test_class do
    Class.new(RoadForest::Interface::RDF) do
      def self.path_params
        [:id, :parm_one, :parm_two]
      end
    end
  end

  let :dispatcher do
    RoadForest::Dispatcher.new(services).tap do |route|
      route.add :dest, ["dest", :id], :leaf, dest_test_class
    end
  end

  let :path_provider do
    RoadForest::PathProvider.new(:source, dispatcher)
  end

  let :graph do
    ::RDF::Graph.new
  end

  let :builder do
    RoadForest::Graph::NavAffordanceBuilder.new(graph, path_provider)
  end

  it "should add affordance statements to the graph" do
    builder.to(:dest)

    graph.should match_query{
      pattern [ :aff, ::RDF.type, RoadForest::Graph::Af.Navigate ]
      pattern [ :aff, RoadForest::Graph::Af.target, :tmpl ]
      pattern [ :tmpl, RoadForest::Graph::Af.pattern, "http://example.com/dest{/id}{?parm_one,parm_two}" ]
    }
  end

  it "should add affordance statements to the graph" do
    builder.to(:dest, :id => 7)

    graph.should match_query{
      pattern [ :aff, ::RDF.type, RoadForest::Graph::Af.Navigate ]
      pattern [ :aff, RoadForest::Graph::Af.target, :tmpl ]
      pattern [ :tmpl, RoadForest::Graph::Af.pattern, "http://example.com/dest/7{?parm_one,parm_two}" ]
    }
  end

  it "should add affordance statements to the graph" do
    builder.to(:dest, :parm_one => 7)

    graph.should match_query{
      pattern [ :aff, ::RDF.type, RoadForest::Graph::Af.Navigate ]
      pattern [ :aff, RoadForest::Graph::Af.target, :tmpl ]
      pattern [ :tmpl, RoadForest::Graph::Af.pattern, "http://example.com/dest{/id}?parm_one=7{?parm_two}" ]
    }
  end
end
