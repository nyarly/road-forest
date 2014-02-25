require 'webmachine/application'
module RoadForest
  class Application < Webmachine::Application; end
end

require 'roadforest/application/dispatcher'
require 'roadforest/application/path-provider'
require 'roadforest/application/services-host'
require 'roadforest/resource/rdf'
require 'roadforest/content-handling/common-engines'
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

    attr_accessor :services, :canonical_host, :default_content_engine

    alias router dispatcher

    #XXX Is this the right place for this?
    def services=(service_host)
      @services = service_host
      service_host.application = self
    end

    def default_content_engine
      @default_content_engine || ContentHandling.rdf_engine
    end
  end
end
