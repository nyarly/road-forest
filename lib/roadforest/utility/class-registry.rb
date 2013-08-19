module RoadForest
  module Utility
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
          (
            class << mod; self; end
          ).define_method :registrar do
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
  end
end
