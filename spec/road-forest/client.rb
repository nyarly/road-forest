require 'road-forest/client'
require 'road-forest/server'
require 'road-forest/test-support'

describe RoadForest::RemoteHost do
  let :services do
    RFTest::ServicesHost.new.tap do |host|
      host.file_records = [
        RFTest::FileRecord.new("one", false),
        RFTest::FileRecord.new("two", false),
        RFTest::FileRecord.new("three", false)
      ]
    end
  end

  let :server do
    RoadForest::TestSupport::RemoteHost.new(RFTest::Application.new("http://road-forest.test-domain.com/", services))
  end

  describe "putting data to server" do

    before :each do
      begin
        server.putting do |graph|
          items = graph.all(:nav, "item")

          unresolved = items.find do |nav_item|
            nav_item[:nav, "label"] == "Unresolved"
          end

          target = unresolved.first(:nav, "target")

          needs = target.first(:lc, "needs").as_list

          needs.each do |need|
            need[[:lc, "resolved"]] = true
          end
        end
      rescue
        raise
      end
    end

    it "should change the server state" do
      tracing = true
      tracing = false
      if tracing
        Webmachine::Trace.traces.each do |trace|
          pp [trace, Webmachine::Trace.fetch(trace)]
        end
      end

      services.file_records.each do |record|
        record.resolved.should == true
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

  class ServicesHost < ::RoadForest::ServicesHost
    attr_accessor :file_records

    def initialize
      @file_records = []
    end
  end

  FileRecord = Struct.new(:name, :resolved)


  class Application < RoadForest::Application
    def setup
      router.add  :root,              [],                    :read_only,     Models::Navigation
      router.add  :unresolved_needs,  ["unresolved_needs"],  :parent,        Models::UnresolvedNeedsList
      router.add_traced  :need,              ["needs",'*'],         :leaf,          Models::Need
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
            services.file_records.each do |record|
              if !record.resolved
                list << path_for(:need, '*' => record.name)
              end
            end
          end
        end
      end

      class Need < RoadForest::Model
        def data
          @data ||= services.file_records.find do |record|
            record.name == params.remainder
          end
        end

        def update(results)
          graph = results.start_graph
          data.resolved = graph[[:lc, "resolved"]]
        end

        def fill_graph(graph)
          graph[[:lc, "resolved"]] = data.resolved
        end
      end
    end
  end
end
