class RoadForest::RDF::SourceRigor
  module Credence
    require 'roadforest/rdf/source-rigor/credence/role-if-available'
    require 'roadforest/rdf/source-rigor/credence/any'
    require 'roadforest/rdf/source-rigor/credence/none-if-role-absent'

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
  end
end
