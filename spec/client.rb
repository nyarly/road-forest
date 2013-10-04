require 'roadforest/server'
require 'roadforest/test-support'

require 'examples/file-management'

describe RoadForest::RemoteHost do
  let :destination_dir do
    "spec_support/destination"
  end

  let :source_path do
    "spec_support/test-file.txt"
  end

  let :services do
    require 'logger'
    FileManagementExample::ServicesHost.new.tap do |host|
      host.file_records = [
        FileManagementExample::FileRecord.new("one", false),
        FileManagementExample::FileRecord.new("two", false),
        FileManagementExample::FileRecord.new("three", false)
      ]
      host.destination_dir = destination_dir
      host.logger = Logger.new($stdout)
      host.logger.level = Logger::DEBUG
    end
  end

  let :server do
    RoadForest::TestSupport::RemoteHost.new(FileManagementExample::Application.new("http://localhost:8778", services))
  end

  def dump_trace
    tracing = true
    tracing = false
    if tracing
      RoadForest::TestSupport::FSM.dump_trace
    end
  end

  before :each do
    RoadForest::TestSupport::FSM.trace_on
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
        items = graph.all(:skos, "hasTopConcept")

        unresolved = items.find do |nav_item|
          nav_item[:skos, "label"] == "Unresolved"
        end

        target = unresolved.first(:foaf, "page")

        @destination = target.first(:lc, "needs").as_list.first[:lc, "contents"]
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
      @destination.to_context.to_s.should == "http://localhost:8778/files/one"
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
          items = graph.all(:skos, "hasTopConcept")

          unresolved = items.find do |nav_item|
            nav_item[:skos, "label"] == "Unresolved"
          end

          target = unresolved.first(:foaf, "page")

          target.post_to do |new_need|
            new_need[[:lc, "name"]] = "lawyers/guns/money"
          end
        end
      ensure
        dump_trace
      end
    end

    it "should change the server state" do
      services.file_records.find do |record|
        record.name == "lawyers/guns/money"
      end.should be_an_instance_of FileManagementExample::FileRecord
    end
  end

  describe "putting data to server" do
    before :each do
      server.putting do |graph|
        puts "\n#{__FILE__}:#{__LINE__} => #{graph.inspect}"
        puts "\n#{__FILE__}:#{__LINE__} => \n#{graph.source_graph.dump(:nquads)}"
        items = graph.all(:skos, "hasTopConcept")

        unresolved = items.find do |nav_item|
          nav_item[:skos, "label"] == "Unresolved"
        end

        target = unresolved.first(:foaf, "page")

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

    it "should change the server's responses" do
      server.getting do |graph|
        @correct = 0
        items = graph.all(:skos, "hasTopConcept")

        unresolved = items.find do |nav_item|
          nav_item[:skos, "label"] == "Unresolved"
        end

        unresolved.first(:foaf, "page").first(:lc, "needs").as_list.each do |need|
          @correct += 1
        end
      end

      @correct.should == 0
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
