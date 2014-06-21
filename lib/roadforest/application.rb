require 'webmachine/application'
module RoadForest
  class Application < Webmachine::Application; end
end

require 'roadforest/application/dispatcher'
require 'roadforest/application/path-provider'
require 'roadforest/application/services-host'
require 'roadforest/resource'
require 'roadforest/content-handling/common-engines'
require 'roadforest/graph/normalization'
require 'roadforest/authorization'

module RoadForest
  class Application
    def initialize(services, configuration = nil)
      @services = services
      configuration ||= Webmachine::Configuration.default
      super(configuration, dispatcher)
    end

    attr_reader :services

    def dispatcher
      services.dispatcher
    end
    alias router dispatcher

    def canonical_host
      services.canonical_host
    end

    def default_content_engine
      services.default_content_engine
    end
  end
end
