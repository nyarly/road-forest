module RoadForest
  class Application
    #XXX Worth doing some meta to get reality checking of configs here? Better
    #fail early if there's no DB configured, right?
    class ServicesHost
      def initialize
      end

      attr_writer :application
      attr_writer :router, :canonical_host, :type_handling
      attr_writer :logger, :authorization

      def canonical_host
        @application.canonical_host
      end

      def router
        @router ||= PathProvider.new(@application.dispatcher)
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

      alias authz authorization
    end
  end
end
