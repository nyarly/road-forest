require 'roadforest/path-matcher'
require 'roadforest/test-support/matchers'

describe "Path matching" do
  let :path do
    RoadForest::Graph::Path
  end

  let :voc do
    ::RDF::Vocabulary.new("http://example.com/voc#")
  end

  let :pattern do
    root = ::RDF::Node.new(:root)
    seg1 = ::RDF::Node.new(:seg1)
    seg2 = ::RDF::Node.new(:seg2)
    ::RDF::Graph.new.tap do |graph|
      graph << [ root, RDF::RDFS.class, path.Root ]
      graph << [ root, path.forward, seg1 ]
      graph << [ seg1, path.predicate, voc.one ]
      graph << [ seg1, path.forward, seg2 ]
      graph << [ seg2, path.predicate, voc.two ]
    end
  end

  let :root_node do
    ::RDF::Node.new(:start)
  end

  let :match_against do
    ::RDF::Graph.new.tap do |graph|
      graph << [root_node, voc.one, :middle ]
      graph << [:middle, voc.two, :end ]
    end

  end

  let :matcher do
    RoadForest::PathMatcher.new.tap do |matcher|
      matcher.pattern = pattern
    end
  end

  let :match do
    matcher.match(root_node, match_against)
  end

  describe RoadForest::PathMatcher::Node do
    let :node do
      RoadForest::PathMatcher::Node.new do |node|
        node.pattern = pattern
        node.graph = match_against
      end
    end

    it "should not generate child edges when checked for resolution" do
      expect do
        node.resolved?.should be_false
        node.rejecting?.should be_false
        node.accepting?.should be_false
      end.not_to change{node.child_edges}

      node.child_edges.should be_nil
    end
  end

  describe RoadForest::PathMatcher::Edge do
    let :edge do
      RoadForest::PathMatcher::Edge.new do |edge|
        edge.pattern = pattern
        edge.graph = match_against

        edge.edge_kind = RoadForest::Graph::Path.forward
      end
    end

    it "should not generate child edges when checked for resolution" do
      expect do
        edge.resolved?.should be_false
        edge.rejecting?.should be_false
        edge.accepting?.should be_false
      end.not_to change{edge.child_nodes}

      edge.child_nodes.should be_nil
    end
  end

  it "should extract the subgraph" do
    subgraph = match.graph
    subgraph.should be_equivalent_to(match_against)
  end

  #ambiguous matches
  #missing root node
  #path unmatched
  #debugging list of matching attempts
  #
  describe "on an rdf:List" do
  end

  describe "on a binary tree" do
  end
end
