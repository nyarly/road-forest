require 'roadforest/utility/class-registry'
require 'roadforest/graph/vocabulary'

module RoadForest
  module AffordanceClient
    Af = Graph::Af
    def all_affordances
      @all_affordances ||=
        [
          Af.Affordance,
          Af.Null,
          Af.Safe,
          Af.Idempotent,
          Af.Unsafe,
          Af.Navigate,
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
      return false #to be implemented
      query_matches(has_affordance(node, :Navigate) + payload_has_param(node), graph)
    end
  end

  module MediaType
    class RDFaWriter
      class DecorationSet
        def initialize
          @names = EnvironmentDecorator.all_names
        end
        attr_accessor :names

        def decoration_for(env)
          names.inject(env) do |env, name|
            EnvironmentDecorator[name].perhaps_decorate(env)
          end
        end
      end

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

        end

        def initialize(env)
          @_decorated_ = env
          setup
        end

        def setup
        end

        def like_a?(klass)
          is_a?(klass) || _decorated_.like_a?(klass)
        end

        attr_reader :_decorated_
      end

      class RDFPostCurie < RenderEnvironment
        def initialize(engine, kind, uri)
          super(engine)
          @kind, @uri = kind, uri
        end

        attr_reader :kind, :uri

        def curie
          @curie ||= get_curie(uri)
        end

        def reduced?
          curie != uri
        end

        def prefix
          @prefix ||= curie.split(":").first
        end

        def suffix
          @suffix ||= curie.split(":").last
        end

        def template_kinds
          %w{rdfpost-curie}
        end
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

        def rdfpost_curie(kind, uri)
          curie = RDFPostCurie.new(_engine, kind, uri)

          _engine.render(curie)
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
          return false unless env._base_env_.class <= SubjectEnvironment
          return false unless env.parent.like_a? AffordanceDecorator

          return (
            [:Update, :Remove, :Create].find do |type|
            affordance_type_in_graph?(env.subject, type, env._engine.graph)
            end || parameterized_navigation_affordance_in_graph?(env.subject, env._engine.graph))
        end

        def predicate_nodes
          @predicate_nodes ||=
            begin
              [].tap do |nodes|
                each_predicate do |pred|
                  pred.each_object do |object|
                    subj = _engine.subject_env(object)
                    next if subj.nil?
                    subj.rel = get_curie(pred.predicate)
                    nodes << subj
                  end
                end
              end
            end
          @predicate_nodes.enum_for(:each)
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

        def self.can_decorate?(env)
          return false unless (env._base_env_.class <= PropertyEnvironment)
          return false unless (env.parent.like_a? AffordanceDecorator)
          return true
        end

      end

      class ObjectAffordanceDecorator < AffordanceDecorator
        decorates ObjectEnvironment

        def self.can_decorate?(env)
          return false unless env._base_env_.class <= ObjectEnvironment
          return false unless env.parent.like_a? AffordanceDecorator
          return true
        end

        def label_attrs
          {}
        end

        def type_uri
          if object.literal? and object.datatype?
            object.datatype
          end
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
