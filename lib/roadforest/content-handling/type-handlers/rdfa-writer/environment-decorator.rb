require 'roadforest/utility/class-registry'
require 'roadforest/rdf/vocabulary'

module RoadForest
  module AffordanceClient
    Af = RDF::Af
    def all_affordances
      @all_affordances ||=
        [
          Af.Affordance,
          Af.Null,
          Af.Safe,
          Af.Idempotent,
          Af.Unsafe,
          Af.Navigation,
          Af.Embed,
          Af.Metadata,
          Af.Update,
          Af.Remove,
          Af.Create,
          Af.Mutate,
      ]
    end

    def affordance_present(aff)
      ::RDF::Query.new do
        pattern [:any, ::RDF.type, aff ]
      end
    end

    def has_affordance(node, type)
      if type.is_a? Symbol
        type = Af[type]
      end
      ::RDF::Query.new do
        pattern([:node, ::RDF.type, type, nil])
        pattern([:node, Af.target, node, nil])
      end
    end

    def payload_has_param(node)
      ::RDF::Query.new do
        pattern([:node, Af.payload, :context, nil])
        pattern([ :param, ::RDF.type, Af.Parameter, :context ])
      end
    end

    def query_matches(query, graph)
      return (not graph.first(query).nil?)
    end

    def affordances_in_graph?(graph)
      all_affordances.each do |aff|
        return true if query_matches(affordance_present(aff), graph)
      end
      return false
    end

    def affordance_node?(node, graph)
      query = ::RDF::Query.new do
        pattern [node, ::RDF.type, :type]
      end
      !!( query.execute(graph).find do |solution|
        all_affordances.include?(solution[:type])
      end)
    end

    def affordance_type_in_graph?(node, type, graph)
      #puts "\n#{__FILE__}:#{__LINE__} => \n#{graph.dump(:nquads)}"
      query_matches(has_affordance(node, type).tap{|value|
        #puts "#{__FILE__}:#{__LINE__} => #{[value.patterns,
        #value.execute(graph)].inspect}"
      }, graph).tap{|value|
        #puts "#{__FILE__}:#{__LINE__} => #{value.inspect}"
      }
    end

    def parameterized_navigation_affordance_in_graph?(node, graph)
      query_matches(has_affordance(node, :Navigation) + payload_has_param(node), graph)
    end
  end

  module MediaType
    class RDFaWriter
      class EnvironmentDecorator
        extend Utility::ClassRegistry::Registrar

        class << self
          def registry_purpose
            "render environment decoration"
          end

          def decorates(klass)
            register(self.name)
            @decorated_class = klass
            methods = klass.instance_methods
            methods -= self.instance_methods
            methods.each do |method|
              define_method(method) do |*args, &block|
                @_decorated_.__send__(method, *args, &block)
              end
            end
          end

          def can_decorate?(env)
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
          @_decorated_ = env
          setup
        end

        def setup
        end

        attr_reader :_decorated_
      end

      class AffordanceDecorator < EnvironmentDecorator
        include AffordanceClient
        extend AffordanceClient

        def graph
          _engine.graph
        end

        def affordance?
          true
        end

        def template_kinds
          _base_env_.template_kinds.map{|kind| "affordance-" + kind} + _base_env_.template_kinds
        end
      end

      class DocumentAffordanceDecorator < AffordanceDecorator
        decorates DocumentEnvironment

        def self.can_decorate?(env)
          return false unless env._base_env_.class <= DocumentEnvironment
          affordances_in_graph?(env._engine.graph)
        end


        def subjects
          _decorated_.subjects.reject do |subject_env|
            affordance_node?(subject_env.subject, graph)
          end
        end

        def prefixes
          dec_prefixes = _decorated_.prefixes

          dec_prefixes.keys.find_all do |key|
            dec_prefixes[key] == Af.to_uri
          end.each do |key|
            dec_prefixes.delete(key)
          end
          dec_prefixes
        end

        def prefix
          @prefix ||= build_prefix_header(prefixes)
        end
      end

      class SubjectAffordanceDecorator < AffordanceDecorator
        decorates SubjectEnvironment

        def self.can_decorate?(env)
          (env._base_env_.class <= SubjectEnvironment) &&
            (
              [:Update, :Remove, :Create].find do |type|
              affordance_type_in_graph?(env.subject, type, env._engine.graph)
            end || parameterized_navigation_affordance_in_graph?(env.subject, env._engine.graph))
        end

        def prefixes
          _engine.prefixes
        end

        def attrs
          _decorated_.attrs.merge(
            :method => "POST", :action => subject.join("put")
          )
        end
      end

      class PropertyAffordanceDecorator < AffordanceDecorator
        decorates PropertyEnvironment

        def curie_prefix
          @curie_prefix ||= get_curie(predicate).split(":").first
        end

        def curie_suffix
          @curie_suffix ||= get_curie(predicate).split(":").last
        end
      end

      class ObjectAffordanceDecorator < AffordanceDecorator
        decorates ObjectEnvironment

        def label_attrs
          {}
        end

        def input_attrs(value)
          @_decorated_.attrs.merge(
            :name => "ol",
            :content => value,
            :value => value,
          )
        end
      end
    end
  end
end
