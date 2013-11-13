require 'webmachine/application'
module RoadForest
  class Application < Webmachine::Application; end
end

require 'roadforest/application/dispatcher'
require 'roadforest/application/path-provider'
require 'roadforest/application/services-host'
require 'roadforest/resource/rdf'
require 'roadforest/content-handling/engine'
require 'roadforest/rdf/normalization'
require 'roadforest/authorization'

module RoadForest
  class Application
    include RDF::Normalization

    def initialize(canonical_host, services = nil, configuration = nil, dispatcher = nil)
      @canonical_host = normalize_resource(canonical_host)
      configuration ||= Webmachine::Configuration.default
      dispatcher ||= Dispatcher.new(self)
      super(configuration, dispatcher)
      self.services = services unless services.nil?

      setup
    end

    def setup
    end

    attr_accessor :services, :canonical_host

    alias router dispatcher

    #XXX Is this the right place for this?
    def services=(service_host)
      @services = service_host
      service_host.application = self
      @services.canonical_host = canonical_host
      @services.router = PathProvider.new(@dispatcher)
    end
  end
end
