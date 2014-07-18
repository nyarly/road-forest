module RoadForest
  class Application
    #XXX Worth doing some meta to get reality checking of configs here? Better
    #fail early if there's no DB configured, right?
    class ServicesHost
      include Graph::Normalization

      def initialize
      end

      attr_writer :application
      attr_writer :router, :canonical_host, :type_handling
      attr_writer :logger, :authorization
      attr_accessor :root_url

      attr_accessor :default_content_engine

      def canonical_host
        @canonical_host ||= normalize_resource(@root_url)
      end

      def dispatcher
        @dispatcher ||= Dispatcher.new(self)
      end
      alias router dispatcher

      def path_provider
        @path_provider ||= router.path_provider
      end

      def authorization
        @authorization ||=
          begin
            require 'roadforest/authorization'
            Authorization::Manager.new
          end
      end

      def logger
        @logger ||=
          begin
            require 'logger'
            Logger.new("roadforest.log")
          end
      end

      def default_content_engine
        @default_content_engine || ContentHandling.rdf_engine
      end

      alias authz authorization
    end
  end
end
