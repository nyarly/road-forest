require 'roadforest/server'
require 'roadforest/test-support'

describe RoadForest::RemoteHost do
  let :services do
    RFTest::ServicesHost.new.tap do |host|
      host.file_records = [
        RFTest::FileRecord.new("one", false),
        RFTest::FileRecord.new("two", false),
        RFTest::FileRecord.new("three", false)
      ]
      host.destination_dir = destination_dir
    end
  end

  let :server do
    RoadForest::TestSupport::RemoteHost.new(RFTest::Application.new("http://roadforest.test-domain.com/", services))
  end

  let :tracing do
    true
    false
  end

  let :destination_dir do
    "spec_support/destination"
  end

  let :source_path do
    "spec_support/test-file.txt"
  end

  def trace_on
    RoadForest::TestSupport::FSM.trace_on
  end

  def dump_trace
    RoadForest::TestSupport::FSM.dump_trace
  end

  before :each do
    trace_on
  end

  before :each do
    require 'fileutils'
    FileUtils.rm_f(destination_dir)
    FileUtils.mkdir_p(destination_dir)
  end

  describe "raw put of file data" do
    before :each do
      @destination = nil
      server.getting do |graph|
        items = graph.all(:nav, "item")

        unresolved = items.find do |nav_item|
          nav_item[:nav, "label"] == "Unresolved"
        end

        target = unresolved.first(:nav, "target")

        target.first(:lc, "needs").as_list.each do |need|
          @destination = need[:lc, "contents"]
          break
        end
      end

      unless @destination.nil?
        File::open(source_path) do |file|
          server.put_file(@destination, "text/plain", file)
        end
      end
    end

    it "should be able to format traces correctly" do
      RoadForest::TestSupport::FSM.trace_dump.should =~ /Decision/
    end

    it "should set destination" do
      @destination.to_context.to_s.should == "http://roadforest.test-domain.com/files/one"
    end

    it "should deliver file to destination path" do
      File::read(File::join(destination_dir, "one")).should ==
        File::read(source_path)
    end
  end

  describe "posting data to server" do
    before :each do
      begin
        server.posting do |graph|
          items = graph.all(:nav, "item")

          unresolved = items.find do |nav_item|
            nav_item[:nav, "label"] == "Unresolved"
          end

          target = unresolved.first(:nav, "target")

          target.post_to do |new_need|
            new_need[[:lc, "path"]] = "lawyers/guns/money"
          end
        end
      ensure
        dump_trace if tracing
      end
    end

    it "should change the server state" do
      services.file_records.find do |record|
        record.name == "lawyers/guns/money"
      end.should be_an_instance_of RFTest::FileRecord
    end
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
          need[[:lc, "resolved"]] = true
        end
      end
    end

    it "should change the server state" do
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

  class ServicesHost < ::RoadForest::Application::ServicesHost
    attr_accessor :file_records, :destination_dir

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
      router.add  :file_content,      ["files", "*"],        :leaf,          Models::NeedContent
    end

    module Models
      class Navigation < RoadForest::RDFModel
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

      class UnresolvedNeedsList < RoadForest::RDFModel
        def exists?
          true
        end

        def update(graph)
        end

        def add_child(graph)
          new_file = FileRecord.new(graph.first(:lc, "path"), false)
          services.file_records << new_file
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

      class NeedContent < RoadForest::BlobModel
        add_type "text/plain", TypeHandlers::Handler.new
      end

      class Need < RoadForest::RDFModel
        def data
          @data = services.file_records.find do |record|
            record.name == params.remainder
          end
        end

        def graph_update(graph)
          data.resolved = graph[[:lc, "resolved"]]
          new_graph
        end

        def fill_graph(graph)
          graph[[:lc, "resolved"]] = data.resolved
          graph[[:lc, "name"]] = data.name
          graph[[:lc, "contents"]] = path_for(:file_content)
        end
      end
    end
  end
end
