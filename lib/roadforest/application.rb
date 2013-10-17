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
require 'roadforest/rdf/normalization'

module RoadForest
  class Application
    include RDF::Normalization

    def initialize(canonical_host, services = nil, configuration = nil, dispatcher = nil)
      @canonical_host = normalize_resource(canonical_host)
      configuration ||= Webmachine::Configuration.default
      dispatcher ||= Dispatcher.new(services)
      super(configuration, dispatcher)
      self.services = services unless services.nil?

      setup
    end

    def setup
    end

    attr_accessor :services, :canonical_host

    alias router dispatcher

    def services=(service_host)
      router.services = service_host
      @services = service_host
      @services.canonical_host = canonical_host
      @services.router = PathProvider.new(@dispatcher)
      @services.type_handling ||= ContentHandling::Engine.default
      @services.logger ||=
        begin
          require 'logger'
          Logger.new("roadforest.log")
        end
    end
  end
end
