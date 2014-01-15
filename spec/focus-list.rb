require 'rdf'
require 'roadforest/rdf/focus-list'
require 'roadforest/rdf/graph-focus'

describe RoadForest::RDF::FocusList do
  let :graph do
    RDF::Graph.new
  end

  let :access do
    RoadForest::RDF::WriteManager.new.tap do |access|
      access.source_graph = graph
    end
  end

  let :focus do
    RoadForest::RDF::GraphFocus.new(access, "urn:root")
  end

  let :list do
    focus.as_list
  end

  it "should add an item to graph" do
    list.append_node("#test")

    graph.should match_query { |query|
      query.pattern(:object => RDF::URI.new("urn:root#test"))
    }
  end

  it "should add several items to the graph" do
    list.append_node("#1")
    list.append_node("#2")
    list.append_node("#3")

    focus.as_list.to_a.should have(3).nodes

  end
end
