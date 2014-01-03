require 'roadforest/utility/class-registry'

module RoadForest
  module AffordanceClient
  end

  module MediaType
    class RDFaWriter
      class EnvironmentDecorator < RenderEnvironment
        extend Utility::ClassRegistry::Registrar

        class << self
          def registry_purpose
            "render environment decoration"
          end

          def decorates(klass)
            register(self.name)
            @decorated_class = klass
            methods = klass.instance_methods - BasicObject.instance_methods
            methods -= (self.class.instance_methods - RenderEnvironment.instance_methods)
            methods -= [:_base_env_]
            methods.each do |method|
              define_method(method) do |*args, &block|
                @_base_env_.__send__(method, *args, &block)
              end
            end
          end

          def can_decorate?(env)
            #puts "\n#{__FILE__}:#{__LINE__} => #{[ (env._base_env_.class <
            #@decorated_class), env._base_env_.class, @decorated_class]
            #.inspect}"
            return (env._base_env_.class <= @decorated_class)
          end

          def perhaps_decorate(env)
            if can_decorate?(env)
              self.new(env)
            else
              env
            end
          end

          def decoration_for(env)
            all_names.inject(env) do |env, name|
              get(name).perhaps_decorate(env)
            end
          end
        end

        def initialize(env)
          @_base_env_ = env
        end

        attr_reader :_base_env_
      end

      class AffordanceDecorator < EnvironmentDecorator
        include AffordanceClient
        extend AffordanceClient

      end

      class SubjectAffordanceDecorator < AffordanceDecorator
        decorates SubjectEnvironment
      end

      class PropertyAffordanceDecorator < AffordanceDecorator
        decorates PropertyEnvironment
      end

      class ObjectAffordanceDecorator < AffordanceDecorator
        decorates ObjectEnvironment
      end
    end
  end
end
