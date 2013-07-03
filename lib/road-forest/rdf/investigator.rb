module RoadForest::RDF
  class NoCredibleResults < StandardError; end

  class ClassRegistry
    module Registrar
      def registry
        @registry ||= ClassRegistry.new(self)
      end

      def register(name)
        registrar.registry.add(name, self)
      end

      def [](name)
        registrar.registry.get(name)
      end

      def self.extended(mod)
        (class << mod; self; end).define_method :registrar do
          mod
        end
      end
    end

    def initialize(registrar)
      if registrar.respond_to?(:registry_purpose)
        @purpose = registrar.registry_purpose
      else
        @purpose = registrar.name
      end
      @classes = {}
    end

    def add(name, klass)
      @classes[name.to_sym] = klass
      @classes[name.to_s] = klass
    end

    def get(name)
      @classes.fetch(name)
    rescue KeyError
      raise "No #@purpose class registered as name: #{name.inspect}"
    end
  end

  class Investigator
    extend ClassRegistry::Registrar
    def self.registry_purpose; "investigator"; end

    def pursue(investigation)
      raise NoCredibleResults
    end
  end

  class NullInvestigator < Investigator
    register :null

    def pursue(investigation)
      investigation.results = []
    end
  end

  class HTTPInvestigator < Investigator
    register :http

    def pursue(investigation)
      document = investigation.http_client.get(investigation.context_roles[:subject])
      case document.code
      when (200..299)
        investigation.graph_manager.insert_document(document)
      when (300..399)
        #client should follow redirects
      when (400..499)
      when (500..599)
        raise NotCredible #hrm
      end
    rescue NotCredible
    end
  end
end
