module RoadForest::RDF
  module Credence
    def self.policies
      @policies ||= {
        :any => Any.new,
        :may_subject => RoleIfAvailable.new(:subject),
        :must_subject => NoneIfRoleAbsent.new(:subject),
        :may_local => RoleIfAvailable.new(:local),
        :must_local => NoneIfRoleAbsent.new(:local)
      }
    end

    def self.policy(name)
      if block_given?
        policies[name] ||= yield
      else
        begin
          policies.fetch(name)
        rescue KeyError
          raise "No Credence policy for #{name.inspect} (available named policies are #{policies.keys.inspect})"
        end
      end
    end

    #If there are any results for the subject context, they're good
    class RoleIfAvailable
      def initialize(role)
        @role = role
      end
      attr_reader :role

      def credible(contexts, results)
        if contexts.include?(results.context_roles[role])
          [results.context_roles[role]]
        else
          contexts
        end
      end
    end

    class Any
      def credible(contexts, results)
        contexts
      end
    end

    #Unless we have results for the subject context, nothing is valid
    class NoneIfRoleAbsent
      def initialize(role)
        @role = role
      end
      attr_reader :role

      def credible(contexts, results)
        if contexts.include?(results.context_roles[role])
          contexts
        else
          []
        end
      end
    end
  end
end
