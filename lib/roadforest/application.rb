require 'webmachine/application'
module RoadForest
  class Application < Webmachine::Application; end
end

require 'roadforest/resource/handlers'
require 'roadforest/application/dispatcher'
require 'roadforest/application/path-provider'
require 'roadforest/application/services-host'
require 'roadforest/resource/rdf'
require 'roadforest/content-handling/engine'

module RoadForest
  class Application
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
      @services.type_handling ||= ContentHandling::Engine.default
    end
  end
end