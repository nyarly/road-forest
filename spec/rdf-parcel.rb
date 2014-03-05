require 'roadforest/test-support/matchers'
require 'roadforest/source-rigor/parcel'

describe RoadForest::SourceRigor::Parcel do
  let :literal do
    42
  end

  let :node_a do
    RDF::URI.intern("http://test.org/a")
  end

  let :node_b do
    RDF::URI.intern("http://test.org/b")
  end

  let :node_c do
    RDF::URI.intern("http://test.org/c")
  end

  let :node_a_frag do
    RDF::URI.intern("http://test.org/a#fragment")
  end

  let :node_b_frag do
    RDF::URI.intern("http://test.org/b#fragment")
  end

  let :node_c_frag do
    RDF::URI.intern("http://test.org/c#fragment")
  end

  [:direct_blank_a, :direct_blank_c, :indirect_blank_a, :indirect_blank_c].each do |node|
    let node do
      RDF::Node.new
    end
  end

  let :test_resources do
    [node_a, node_b, node_c]
  end

  let :source_graph do
    pred = RDF::URI.intern("http://generic.com/related_to")
    ::RDF::Graph.new.tap do |graph|
      graph  <<  [  node_a,            pred,  literal           ]
      graph  <<  [  node_a,            pred,  node_b_frag       ]
      graph  <<  [  node_a,            pred,  node_c            ]
      graph  <<  [  node_a,            pred,  direct_blank_a    ]
      graph  <<  [  direct_blank_a,    pred,  indirect_blank_a  ]
      graph  <<  [  node_b,            pred,  node_a            ]
      graph  <<  [  node_b,            pred,  literal           ]
      graph  <<  [  node_b_frag,       pred,  literal           ]
      graph  <<  [  node_b_frag,       pred,  node_a_frag       ]
      graph  <<  [  node_c_frag,       pred,  node_c            ]
      graph  <<  [  node_c_frag,       pred,  indirect_blank_c  ]
      graph  <<  [  indirect_blank_c,  pred,  node_c_frag       ]
    end
  end

  let :parceller do
    RoadForest::SourceRigor::Parcel.new.tap do |parceller|
      parceller.graph = source_graph
    end
  end

  it "should list all subjects" do
    parceller.resources.should include(*test_resources)
  end

  it "should not list any other resource" do
    (parceller.resources - test_resources).should == []
  end

  it "should have graphs for each resource" do
    parceller.resources.each do |resource|
      graph = parceller.graph_for(resource)

      graph.should_not be_nil
      graph.should_not be_empty
    end
  end

  describe "tessellation" do
    let :graph_a do
      parceller.graph_for(node_a).to_a.map(&:to_s)
    end

    let :graph_b do
      parceller.graph_for(node_b).to_a.map(&:to_s)
    end

    let :graph_c do
      parceller.graph_for(node_c).to_a.map(&:to_s)
    end

    let :original do
      source_graph.to_a.map(&:to_s)
    end

    it "should be disjoint" do
      (graph_a & graph_b).should == []
      (graph_a & graph_c).should == []
      (graph_b & graph_a).should == []
      (graph_b & graph_c).should == []
      (graph_c & graph_a).should == []
      (graph_c & graph_b).should == []
    end

    it "should be complete" do
      coverage = graph_a + graph_b + graph_c

      (original - coverage).should == []
      (coverage - original).should == []
    end
  end

  describe "the graph for resource B" do
    let :graph do
      parceller.graph_for(node_b)
    end

    it "should include statements with the resource as subject" do
      statements_from_graph(graph).that_match_query(:subject => node_b).should_not be_empty
    end

    it "should include statements with fragment node" do
      statements_from_graph(graph).that_match_query(:subject => node_b_frag).should_not be_empty
    end
  end

  describe "the graph for resource A" do #needs a much more interesting name
    let :graph do
      parceller.graph_for(node_a)
    end

    it "should include statements with the resource as subject" do
      statements_from_graph(graph).that_match_query(:subject => node_a).should_not be_empty
    end

    it "should include statements about blank nodes within the resource's domain" do
      statements_from_graph(graph).that_match_query(:subject => direct_blank_a).should_not be_empty
    end

    it "should include statements with outside objects" do
      statements_from_graph(graph).that_match_query(:object => node_c).should_not be_empty
    end

    it "should not include statements with b or c as subject" do
      statements_from_graph(graph).that_match_query(:subject => node_b).should be_empty
      statements_from_graph(graph).that_match_query(:subject => node_c).should be_empty
      statements_from_graph(graph).that_match_query(:subject => node_b_frag).should be_empty
      statements_from_graph(graph).that_match_query(:subject => node_c_frag).should be_empty
      statements_from_graph(graph).that_match_query(:subject => direct_blank_c).should be_empty
      statements_from_graph(graph).that_match_query(:subject => indirect_blank_c).should be_empty
    end
  end
end
