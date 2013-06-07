describe RoadForest::RDF::Parcel do
  let :source_graph do
    ::RDF::Graph.new
    #with some statements in it
  end

  let :parceller do
    RoadForest::RDF::Parcel.new.tap do |parceller|
      parceller.graph = source_graph
    end
  end

  it "should list all subjects" do
    parceller.resources.should include(test_resources)
  end

  it "should have graphs for each resource" do
    parceller.resources.each do |resource|
      graph = parceller.graph_for(resource)
      graph.should_not be_nil
      graph.should_not be_empty
    end
  end

  describe "the graph for a resource" do
    let :graph do
      graph = parceller.graph_for(test_resources.first)
    end

    it "should include statements with the resource as subject" do

    end

    it "should include statements about blank nodes within the resource's domain" do

    end

    it "should not include other statements" do

    end
  end
end
