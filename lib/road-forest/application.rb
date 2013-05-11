require 'webmachine/application'
require 'road-forest/resource/handlers'
require 'road-forest/dispatcher'
require 'road-forest/path-provider'
require 'road-forest/resource/rdf-handlers'

module RoadForest
  class Application < Webmachine::Application
    include Resource::Handlers

    def initialize(services, configuration = nil, dispatcher = nil)
      configuration ||= Webmachine::Configuration.default
      dispatcher ||= Dispatcher.new(services)
      super(configuration, dispatcher)
      self.services = services

      setup
    end

    def setup
    end

    attr_reader :services

    alias router dispatcher

    def services=(service_host)
      router.services = service_host
      @services = service_host
      @services.router = PathProvider.new(@dispatcher)
    end
  end
end
