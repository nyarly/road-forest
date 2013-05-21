require 'webmachine/application'
require 'road-forest/resource/handlers'
require 'road-forest/dispatcher'
require 'road-forest/path-provider'
require 'road-forest/resource/rdf-handlers'

module RoadForest
  class Application < Webmachine::Application
    include Resource::Handlers

    def initialize(canonical_host, services, configuration = nil, dispatcher = nil)
      @canonical_host = ::RDF::URI.parse(canonical_host)
      configuration ||= Webmachine::Configuration.default
      dispatcher ||= Dispatcher.new(services)
      super(configuration, dispatcher)
      self.services = services

      setup
    end

    def setup
    end

    attr_reader :services, :canonical_host

    alias router dispatcher

    def services=(service_host)
      router.services = service_host
      @services = service_host
      @services.canonical_host = @canonical_host
      @services.router = PathProvider.new(@dispatcher)
    end
  end
end
