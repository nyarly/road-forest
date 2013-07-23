require 'road-forest/client'
require 'road-forest/server'
require 'road-forest/test-support'

describe RoadForest::RemoteHost do
  let :services do
    RoadForest::ServicesHost.new
  end

  let :server do
    RoadForest::TestSupport::RemoteHost.new(RFTest::Application.new("http://road-forest.test-domain.com/", services))
  end

  describe "putting data to server" do

    before :each do
      server.putting do |graph|
        items = graph.all(:nav, "item")

        unresolved = items.find do |nav_item|
          nav_item[:nav, "label"] == "Unresolved"
        end

        target = unresolved.first(:nav, "target")

        needs = target.first(:lc, "needs").as_list

        needs.each do |need|
          need[[:lc, "path"]] = "Manifest"
        end
      end
    end

    it "should extract data from server responses" do
      server.should match_query do
        pattern(:subject, [:lc, "path"], nil)
        pattern(:subject, [:lc, "file"], nil)
      end
    end

    it "should return correct content-type" do
      #test_server.http_exchanges.each{|ex| puts ex.response.body}
      server.http_exchanges.should_not be_empty
      server.http_exchanges.each do |exchange|
        exchange.response.headers["Content-Type"].should == "application/ld+json"
      end
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

        def fill_graph(graph)
          graph[:rdfs, "Class"] = [:nav, "Menu"]
          graph.add_node([:nav, :item], "#unresolved") do |unresolved|
            unresolved[:rdfs, "Class"] = [:nav, "Entry"]
            unresolved[:nav, "label"] = "Unresolved"
            unresolved[:nav, "target"] = path_for(:unresolved_needs)
          end
        end
      end

      class UnresolvedNeedsList < RoadForest::Model
        def exists?
          true
        end

        def update(graph)

        end

        def fill_graph(graph)
          graph.add_list(:lc, "needs") do |list|
            list << path_for(:need, '*' => "test/file")
          end
        end
      end

      class Need < RoadForest::Model
        def exists?
          true
        end

        def update(graph)

        end

        def fill_graph(graph)
          graph[[:lc, "path"]] = params.remainder
          graph[[:lc, "file"]] = "/files/#{params.remainder}"
        end
      end
    end
  end
end
