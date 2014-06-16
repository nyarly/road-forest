require 'roadforest/path-matcher'
require 'roadforest/test-support/matchers'

describe "Path matching" do
  let :path do
    RoadForest::Graph::Path
  end

  let :voc do
    ::RDF::Vocabulary.new("http://example.com/voc#")
  end

  let :root_node do
    ::RDF::Node.new(:start)
  end

  def match(pattern, match_against, root_node)
    matcher = RoadForest::PathMatcher.new.tap do |matcher|
      matcher.pattern = pattern
    end
    matcher.match(root_node, match_against)
  end

  let :pattern do
    root = ::RDF::Node.new(:root)
    seg1 = ::RDF::Node.new(:seg1)
    seg2 = ::RDF::Node.new(:seg2)
    ::RDF::Graph.new.tap do |graph|
      graph << [ root, ::RDF.type, path.Root ]
      graph << [ root, path.forward, seg1 ]
      graph << [ seg1, path.predicate, voc.one ]
      graph << [ seg1, path.forward, seg2 ]
      graph << [ seg2, path.predicate, voc.two ]
    end
  end

  let :match_against do
    middle = ::RDF::Node.new(:middle)
    ::RDF::Graph.new.tap do |graph|
      graph << [root_node, voc.one, middle ]
      graph << [middle, voc.two, :end ]
    end
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

  describe RoadForest::PathMatcher::ForwardEdge do
    let :edge do
      RoadForest::PathMatcher::ForwardEdge.new do |edge|
        edge.pattern = pattern
        edge.graph = match_against
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
    subgraph = match(pattern, match_against, root_node).graph
    subgraph.should be_equivalent_to(match_against)
  end

  it "should succeed" do
    match(pattern, match_against, root_node).should be_successful
  end

  describe "reuse" do
    let :pattern do
      root = ::RDF::Node.new(:root)
      lit1 = ::RDF::Node.new(:lit1)

      ::RDF::Graph.new.tap do |graph|
        graph << [ root, ::RDF.type, path.Root ]
        graph << [ root, path.forward, lit1 ]
        graph << [ lit1, path.predicate, voc.one ]
        graph << [ lit1, path.type, ::RDF::XSD.integer ]
      end
    end

    let :matcher do
      RoadForest::PathMatcher.new.tap do |matcher|
        matcher.pattern = pattern
      end
    end

    let :haystack_one do
      ::RDF::Graph.new.tap do |graph|
        graph << [ root_node, voc.one, 3 ]
      end

    end

    let :haystack_two do
      ::RDF::Graph.new.tap do |graph|
        graph << [ root_node, voc.one, 4 ]
      end
    end

    let :match_one do
      matcher.match(root_node, haystack_one)
    end

    let :match_two do
      matcher.match(root_node, haystack_two)
    end

    it "should return different matches from different graphs" do
      match_one.should_not == match_two
    end

    it "should return different matched graphs" do
      match_one.graph.should_not == match_two.graph
    end

    it "should return non-equivalent matched graphs" do
      match_one.graph.should_not be_equivalent_to(match_two.graph)
    end

    it "should not mutate graphs after the fact" do
      prior = match_one.graph.dup
      match_two
      prior.should be_equivalent_to(match_one.graph)
    end
  end

  describe "literal constraints" do
    let :match_against do
      ::RDF::Graph.new.tap do |graph|
        graph << [ root_node, voc.one, 3 ]
        graph << [ root_node, voc.one, 4 ]
      end
    end

    let :pattern do
      root = ::RDF::Node.new(:root)
      lit1 = ::RDF::Node.new(:lit1)

      ::RDF::Graph.new.tap do |graph|
        graph << [ root, ::RDF.type, path.Root ]
        graph << [ root, path.forward, lit1 ]
        graph << [ lit1, path.predicate, voc.one ]
        graph << [ lit1, path.type, ::RDF::XSD.integer ]
        graph << [ lit1, path.is, 3 ]
      end
    end

    it "should succeed" do
      match(pattern, match_against, root_node).should be_successful
    end

    it "should only have the matching item" do
      graph = match(pattern, match_against, root_node).graph
      v = voc
      graph.should match_query { pattern [ :start, v.one, 3 ] }
      graph.should_not match_query { pattern [ :start, v.one, 4 ] }
    end
  end

  describe "type contraints" do
    let :match_against do
      ::RDF::Graph.new.tap do |graph|
        graph << [ root_node, voc.one, 3 ]
        graph << [ root_node, voc.one, "Humphrey Bogart" ]
      end
    end

    let :pattern do
      root = ::RDF::Node.new(:root)
      lit1 = ::RDF::Node.new(:lit1)

      ::RDF::Graph.new.tap do |graph|
        graph << [ root, ::RDF.type, path.Root ]
        graph << [ root, path.forward, lit1 ]
        graph << [ lit1, path.predicate, voc.one ]
        graph << [ lit1, path.type, ::RDF::XSD.integer ]
      end
    end

    it "should succeed" do
      match(pattern, match_against, root_node).should be_successful
    end

    it "should only have the matching items" do
      graph = match(pattern, match_against, root_node).graph
      v = voc
      graph.should match_query { pattern [ :start, v.one, 3 ] }
      graph.should_not match_query { pattern [ :start, v.one, "Humphrey Bogart" ] }
    end

  end

  describe "repeats" do
    def match_against(depth)
      ::RDF::List.new(root_node, ::RDF::Graph.new, (1..depth).to_a)
    end

    let :pattern do
      root = ::RDF::Node.new(:root)
      lit1 = ::RDF::Node.new(:lit1)

      ::RDF::Graph.new.tap do |graph|
        graph << [ root, ::RDF.type, path.Root ]
        graph << [ root, path.forward, lit1 ]
        graph << [ lit1, path.predicate, ::RDF.first ]
        graph << [ lit1, path.type, ::RDF::XSD.integer ]
        graph << [ root, path.forward, root ]
        graph << [ root, path.predicate, ::RDF.rest ]
        graph << [ root, path.minRepeat, 2 ]
        graph << [ root, path.maxRepeat, 4 ]
      end
    end

    it "should reject unless min repeats present" do
      list = match_against(2)
      root = list.subject
      graph = list.graph
      match(pattern, graph, root).should_not be_successful
    end

    it "should match a mid-sized graph" do
      list = match_against(4)
      root = list.subject
      graph = list.graph
      matching = match(pattern, graph, root)
      matching.should be_successful
      matching.graph.query(:predicate => ::RDF.rest).to_a.length.should == 3
    end

    it "should match up to the number of repeats" do
      list = match_against(5)
      root = list.subject
      graph = list.graph
      matching = match(pattern, graph, root)
      matching.should be_successful
      matching.graph.query(:predicate => ::RDF.rest).to_a.length.should == 4
    end
  end

  describe "multiple" do
    let :pattern do
      root = ::RDF::Node.new(:root)
      seg1 = ::RDF::Node.new(:seg1)
      seg2 = ::RDF::Node.new(:seg2)
      ::RDF::Graph.new.tap do |graph|
        graph << [ root, ::RDF.type, path.Root ]
        graph << [ root, path.forward, seg1 ]
        graph << [ seg1, path.predicate, voc.one ]
        graph << [ seg1, path.minMulti, 2 ]
        graph << [ seg1, path.maxMulti, 5 ]
      end
    end

    let :unbounded_pattern do
      root = ::RDF::Node.new(:root)
      seg1 = ::RDF::Node.new(:seg1)
      ::RDF::Graph.new.tap do |graph|
        graph << [ root, ::RDF.type, path.Root ]
        graph << [ root, path.forward, seg1 ]
        graph << [ seg1, path.predicate, voc.one ]
        graph << [ seg1, path.minMulti, 0 ]
      end
    end

    let :match_against do
      ::RDF::Graph.new.tap do |graph|
        graph << [root_node, voc.one, :one ]
        graph << [root_node, voc.one, :two ]
        graph << [root_node, voc.one, :three ]
      end
    end

    let :only_one do
      ::RDF::Graph.new.tap do |graph|
        graph << [root_node, voc.one, :one ]
      end
    end

    let :cripes_six do
      ::RDF::Graph.new.tap do |graph|
        graph << [root_node, voc.one, :one ]
        graph << [root_node, voc.one, :two ]
        graph << [root_node, voc.one, :three ]
        graph << [root_node, voc.one, :four ]
        graph << [root_node, voc.one, :five ]
        graph << [root_node, voc.one, :six ]
      end
    end

    it "should extract the subgraph" do
      subgraph = match(pattern, match_against, root_node).graph
      subgraph.should be_equivalent_to(match_against)
    end

    it "should not match too few fanout" do
      match(pattern, only_one, root_node).success?.should be_false
    end

    it "should not match too many fanout" do
      match(pattern, cripes_six, root_node).success?.should be_false
    end

    it "should handle no limits" do
      match(unbounded_pattern, only_one, root_node).success?.should be_true
      match(unbounded_pattern, cripes_six, root_node).success?.should be_true
    end
  end

  #exact value matches
  #ambiguous matches
  #missing root node
  #path unmatched
  #debugging list of matching attempts
  #
  describe "on a binary tree" do
  end
end
