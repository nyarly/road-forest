require 'rdf'
require 'roadforest/rdf/focus-list'
require 'roadforest/rdf/graph-focus'

describe RoadForest::RDF::FocusList do
  let :graph do
    RDF::Graph.new
  end

  let :focus do
    RoadForest::RDF::GraphFocus.new("urn:root", graph)
  end

  let :list do
    focus.as_list
  end

  it "should add an item to graph" do
    list.append_node("#test")

    graph.should match_query do |query|
      query.pattern(:subject => "urn:root#test")
    end
  end

  it "should add several items to the graph" do
    list.append_node("#1")
    list.append_node("#2")
    list.append_node("#3")

    focus.as_list.to_a.should have(3).nodes

  end
end
