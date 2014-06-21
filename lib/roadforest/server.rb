#This file is intended as the single entry point for RoadForest server code
require 'roadforest/application'
require 'roadforest/interfaces'

module RoadForest
  def self.serve(services)
    require 'webrick/accesslog'

    application = RoadForest::Application.new(services)

    logfile = services.logger
    logfile.info("#{Time.now.to_s}: Starting Roadforest server")

    application.configure do |config|
      config.adapter_options = {
        :Logger => WEBrick::Log.new(logfile),
        :AccessLog => [
          [logfile, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
          [logfile, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
      ]
      }
      yield config if block_given?
    end
    application.run
  end
end
