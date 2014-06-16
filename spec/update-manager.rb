describe RoadForest::SourceRigor::UpdateManager do
  let :graph_store do
    ::RDF::Graph.new.tap do |source|
      original_statements.each do |stmt|
        source << stmt
      end
    end
  end

  let :original_statements do
    []
  end

  let :source_rigor do
    RoadForest::SourceRigor.simple
  end

  let :manager do
    RoadForest::SourceRigor::UpdateManager.new.tap do |access|
      access.rigor = source_rigor
      access.source_graph = graph_store

      access.reset

      statements.each do |resource, stmt|
        access.resource = resource
        access.insert(stmt)
      end
    end
  end

  let :targets do
    [].tap do |targets|
      manager.each_target do |context, graph|
        targets << [context, graph]
      end
    end
  end

  let :resources do
    targets.map do |resource, graph|
      resource
    end
  end

  describe "with matched payloads" do
    let :af do
      RoadForest::Graph::Af
    end

    let :path do
      RoadForest::Graph::Path
    end

    let :dummy_resource do
      ::RDF::URI.new("urn:local")
    end

    let :original_statements do
      statements = []
      aff_blank = ::RDF::Node.new
      payload_root = ::RDF::Node.new
      payload_name_string = ::RDF::Node.new
      statements += [
        [ aff_blank, ::RDF::RDFV.type, af.Update ],
        [ aff_blank, af.target,
          ::RDF::URI.new("http://localhost:8778/needs/one") ],
          [ aff_blank, af.payload, payload_root ]
      ]
      statements += [
        [ payload_root, ::RDF::RDFV.type, path.Root ],
        [ payload_root, path.forward, payload_name_string],
        [ payload_name_string, path.predicate, ::RDF::URI.new("http://lrdesign.com/vocabularies/logical-construct#name") ],
        [ payload_name_string, path.type, ::RDF::XSD.string ]
      ]
      statements
    end

    let :statements do
      statements = []
      statements += [
          [
          ::RDF::URI.new("http://localhost:8778/needs/one"),
          ::RDF::URI.new("http://lrdesign.com/vocabularies/logical-construct#name"),
          "one" ]
      ]
      statements.map do |stmt|
        [ dummy_resource, stmt ]
      end
    end

    it "should match payloads" do
      count = 0
      manager.each_payload do
        count += 1
      end
      count.should > 0
    end

    it "should get the right resources" do
      resources.should_not include(dummy_resource)
    end

    it "should match subgraphs to payloads" do
      targets.length.should == 1
      targets.first.first.to_s.should == "http://localhost:8778/needs/one"
      targets.first.last.statements.to_a.length.should == 1
    end
  end

  describe "without payload paths" do
    let :statements do
      [
        [::RDF::URI.new("http://localhost:8778/needs/one"),
          [::RDF::URI.new("http://localhost:8778/needs/one"), ::RDF::URI.new("http://lrdesign.com/vocabularies/logical-construct#name"), "one"]]
      ]
    end

    it "should fall back to parcelling" do
      targets.length.should == 1
      targets.first.first.to_s.should == "http://localhost:8778/needs/one"
      targets.first.last.statements.to_a.length.should == 1
    end
  end
end
