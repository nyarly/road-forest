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

  it "should add items to graph" do
    list.append_node("#test")

    graph.should match_query do |query|
      query.pattern(:subject => "urn:root#test")
    end
  end
end
