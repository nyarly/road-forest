module RoadForest
  module Utility
    class ClassRegistry
      #Extend a module with this in order to make it the registrar for a
      #particular purpose.
      #The top of a class heirarchy will make "register" immediately available
      #to subclasses. Otherwise, classes can say Module::registry.add(name,
      #self)
      #
      module Registrar
        def registry
          @registry ||= ClassRegistry.new(self)
        end

        def register(name)
          registrar.registry.add(name, self)
        end

        def get(name)
          registrar.registry.get(name)
        end
        alias [] get

        def all_names
          registrar.registry.names
        end

        def map_classes(&block)
          registrar.map_classes(&block)
        end

        def self.extended(mod)
          (
            class << mod; self; end
          ).instance_exec(mod) do |mod|
            define_method :registrar do
              mod
            end
          end
        end
      end

      def initialize(registrar, purpose=nil)
        if purpose.nil?
          if registrar.respond_to?(:registry_purpose)
            @purpose = registrar.registry_purpose
          else
            @purpose = registrar.name
          end
        else
          @purpose = purpose
        end
        @sequence = NameSequence.new
        @classes = {}
      end

      require 'tsort'
      class NameSequence
        include TSort

        def initialize
          @nodes = Hash.new do |h,k|
            h[k] = []
          end
        end

        def add(before, after)
          @nodes[before] << after
        end

        def exists(node)
          @nodes[node] ||= []
        end

        def tsort_each_node(&block)
          @nodes.each_key(&block)
        end

        def tsort_each_child(node, &block)
          @nodes.fetch(node).each(&block)
        end
      end

      # @yield each class in name order
      def map_classes
        names.map do |name|
          begin
            yield get(name)
          rescue UndefinedClass
            warn "undefined name: #{name} used in sequencing"
          end
        end
      end

      def names
        @sequence.tsort
      end

      def add(name, klass)
        @sequence.exists(name.to_sym)
        @classes[name.to_sym] = klass
        @classes[name.to_s] = klass
      end

      def seq(before, after)
        @sequence.add(before.to_sym, after.to_sym)
      end

      class UndefinedClass < StandardError; end

      def get(name)
        @classes.fetch(name)
      rescue KeyError
        raise UndefinedClass, "No #@purpose class registered as name: #{name.inspect} (there are: #{names.inspect})"
      end
    end
  end
end
