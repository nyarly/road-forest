require 'road-forest/client'
require 'road-forest/server'
require 'road-forest/test-support'

describe RoadForest::RemoteHost do
  let :services do
    RoadForest::ServicesHost.new
  end

  let :test_server do
    RoadForest::TestSupport::RemoteHost.new(RFTest::Application.new("http://road-forest.test-domain.com/", services))
  end

  let :client do
    RFTest::Client.new(test_server)
  end

  it "should extract data from server responses" do
    client.find_needs
    client.needs.should_not be_empty

    test_server.should match_query do
      pattern(:subject, [:lc, "path"], nil)
      pattern(:subject, [:lc, "file"], nil)
    end
  end

  it "should return correct content-type" do
    client.find_needs
    test_server.http_exchanges.should_not be_empty
    test_server.http_exchanges.each do |exchange|
      exchange.response.headers["Content-Type"].should == "application/ld+json"
    end
  end
end

module RFTest
  module Vocabulary
    class LC < ::RDF::Vocabulary("http://lrdesign.com/vocabularies/logical-construct#"); end
    class Nav < ::RDF::Vocabulary("http://lrdesign.com/vocabularies/site-navigation#"); end
  end

  class Application < RoadForest::Application
    def setup
      router.add  :root,              [],                    :read_only,     Models::Navigation
      router.add  :unresolved_needs,  ["unresolved_needs"],  :parent,        Models::UnresolvedNeedsList
      router.add  :need,              ["needs",'*'],         :leaf,          Models::Need
    end

    module Models
      class Navigation < RoadForest::Model
        def exists?
          true
        end

        def update(graph)
          return false
        end

        def retrieve
          new_results do |results|
            graph = results.start_graph(my_path)
            graph[:rdfs, "Class"] = [:nav, "Menu"]
            graph.add_node([:nav, :item], "#unresolved") do |unresolved|
              unresolved[:rdfs, "Class"] = [:nav, "Entry"]
              unresolved[:nav, "label"] = "Unresolved"
              unresolved[:nav, "target"] = path_for(:unresolved_needs)
            end
          end
        end
      end

      class UnresolvedNeedsList < RoadForest::Model
        def exists?
          true
        end

        def update(graph)

        end

        def retrieve
          new_results do |results|
            results.start_graph(my_path) do |graph|
              graph.add_list(:lc, "needs") do |list|
                list << path_for(:need, '*' => "test/file")
              end
            end
          end
        end
      end

      class Need < RoadForest::Model
        def exists?
          true
        end

        def update(graph)

        end

        def retrieve
          new_results do |results|
            results.start_graph(my_path) do |graph|
              graph[[:lc, "path"]] = params.remainder
              graph[[:lc, "file"]] = "/files/#{params.remainder}"
            end
          end
        end
      end
    end
  end

  class Client
    def initialize(server)
      @server = server
    end
    attr_reader :server, :needs


    def find_needs
      server.credence_block do |start|
        @needs = []
        start.all(:nav, "item").find do |nav_item|
          nav_item[:nav, "label"] == "Unresolved"
        end.first(:nav, "target").first(:lc, "needs").as_list.each do |need|
          @needs << [need[:lc, "path"], need[:lc, "file"]]
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
end
