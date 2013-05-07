describe RoadForest::Server do
  let :test_server do
    RoadForest::TestServer.new(TestApplication) do |services|
    end
  end

  let :client do
    TestClient.new(test_server)
  end

  it "should extract data from server responses" do
    client.find_needs
    client.needs.should_not be_empty

    test_server.should have_pattern do
      pattern(:subject, [:lc, "path"], nil)
      pattern(:subject, [:lc, "file"], nil)
    end
  end
end

class TestApplication < RoadForest::Application
  def routes
    :root, [], bundle_model(ReadOnly, Models::Navigation)
    :unresolved_needs, ["unresolved_needs"], bundle_model(List, Models::UnresolvedNeedsList)
    :need, ["needs", '*'], bundle_model(LeafItem, Models::Need)
  end
end

class TestClient
  def initialize(server)
    @server = server
  end
  attr_reader :server

  def find_needs
    needs = server.credence_block do |start|
      start[:lc, "unsatisfied-needs"].all(:lc, "needs").each do |need|
        new_need = need.build_graph do |need|
          need[:lc, "path"]
          need[:lc, "file"]
        end
        #Either
        new_need[[:lc, "file"]] = files.find(new_need[:lc, "path"]).contents
        server.put(new_need)

        #OR

        file = new_need[:lc, "file"]
        server.raw_put(file, files.find(new_need[:lc, "path"])) #mime-type?
      end
    end
  end

  def satisfy(need)
    server.credence_block do |start|
      new_need = start[:lc, "needs"].build_graph do |needs|
        needs[:lc, "need_form"].and_descendants(5) #for a depth stop
      end

      new_need[[:lc, "path"]] = "Manifest"
      server.post(new_need)
    end
  end
end
