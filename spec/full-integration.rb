require 'socket'
require 'rdf'

describe "RoadForest integration", :integration => true do
  class LC < ::RDF::Vocabulary("http://lrdesign.com/vocabularies/logical-construct#"); end
  def kill_server(pid)
    return if pid.nil?
    Process.kill("KILL", pid) rescue nil
    Process.wait(pid)
  rescue Errno::ECHILD
  end

  before :each do
    @server_port = 8778

    begin
      test_conn =  TCPSocket.new 'localhost', @server_port
      raise "Something is still running on localhost:#{@server_port}"
    rescue Errno::ECONNREFUSED
      #That's what we're hoping for
    ensure
      #test_conn.close
    end

    @setup_time_limit = 3
    @destination_dir = "spec_support/destination"
    @server_logs = "integration-tests.log"

    @server_pid = fork do
      require 'roadforest/server'
      require 'examples/file-management'
      require 'webrick/accesslog'
      services = FileManagementExample::ServicesHost.new.tap do |host|
        host.file_records = [
          FileManagementExample::FileRecord.new("one", false),
          FileManagementExample::FileRecord.new("two", false),
          FileManagementExample::FileRecord.new("three", false)
        ]
        host.destination_dir = @destination_dir
      end

      logfile = File::open(@server_logs,"a")
      logfile.sync = true
      logfile.puts "New test run: #{Time.now.to_s}"

      application = FileManagementExample::Application.new("http://localhost:#{@server_port}", services)
      application.configure do |config|
        config.port = @server_port
        config.adapter_options = {
          :Logger => WEBrick::Log.new(logfile),
          :AccessLog => [
            [logfile, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
            [logfile, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
        ]
        }
      end
      application.run
    end

    require 'roadforest/remote-host'

    %w{EXIT TERM}.each do |signal|
      trap(signal) do
        kill_server(@server_pid)
      end
    end

    begin_time = Time.now
    begin
      test_conn =  TCPSocket.new 'localhost', @server_port
    rescue Errno::ECONNREFUSED
      if Time.now - begin_time > @setup_time_limit
        raise "Couldn't connect to test server after #{@setup_time_limit} seconds - bailing out"
      else
        sleep 0.05
        retry
      end
    ensure
      test_conn.close
    end
  end

  after :each do
    kill_server @server_pid
  end

  let :source_path do
    "spec_support/test-file.txt"
  end

  let :server_url do
    "http://localhost:#{@server_port}"
  end

  let :server do
    RoadForest::RemoteHost.new(server_url)
  end

  before :each do
    require 'fileutils'
    FileUtils.rm_f(@destination_dir)
    FileUtils.mkdir_p(@destination_dir)
  end

  def unresolved_list(graph)
    items = graph.all(:skos, "hasTopConcept")

    unresolved = items.find do |nav_item|
      nav_item[:skos, "label"] == "Unresolved"
    end

    return unresolved.first(:foaf, "page")
  end


  describe "raw put of file data" do
    before :each do
      @destination = nil
      server.getting do |graph|
        target = unresolved_list(graph)
        @destination = target.first(:lc, "needs").as_list.first[:lc, "contents"]
      end

      unless @destination.nil?
        File::open(source_path) do |file|
          @response = server.put_file(@destination, "text/plain", file)
        end
      end
    end

    it "should respond with 204" do
      @response.status.should == 204
    end

    it "should set destination" do
      @destination.to_context.to_s.should == "#{server_url}/files/one"
    end

    it "should deliver file to destination path" do
      File::read(File::join(@destination_dir, "one")).should == File::read(source_path)
    end
  end

  describe "posting data to server" do
    before :each do
      server.posting do |graph|
        target = unresolved_list(graph)

        target.post_to do |new_need|
          new_need[[:lc, "name"]] = "lawyers/guns/money"
        end
      end
    end

    it "should change the server state" do
      server.getting do |graph|
        @get_me_out_of_this = unresolved_list(graph).first(:lc, "needs").as_list.find do |need|
          need[:lc, "name"] == "lawyers/guns/money"
        end
      end

      @get_me_out_of_this.should_not be_nil
    end
  end

  describe "getting data from the server" do
    it "should get a correct count" do
      server.getting do |graph|
        @correct = 0
        unresolved_list(graph).first(:lc, "needs").as_list.each do |need|
          @correct += 1 unless need[:lc, "resolved"]
        end
      end

      @correct.should == 3
    end
  end

  describe "putting data to server" do
    before :each do
      server.putting do |graph|
        target = unresolved_list(graph)

        target.first(:lc, "needs").as_list.each do |need|
          need[[:lc, "resolved"]] = true
        end
      end
    end

    it "should change the server state" do
      server.getting do |graph|
        @correct = 0
        unresolved_list(graph).first(:lc, "needs").as_list.each do |need|
          @correct += 1
        end
      end

      @correct.should == 0
    end
  end
end
