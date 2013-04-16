module RoadForest
  class Application < Webmachine::Application
    def initialize(configuration = nil, dispatcher = nil, &block)
      configuration ||= Webmachine::Configuration.default
      dispatcher ||= Dispatcher.new
      super(configuration, dispatcher, &block)
      @services = nil
    end

    attr_reader :services

    def services=(service_host)
      @services = service_host
      @services.router = PathProvider.new(@dispatcher)
    end
  end
end
