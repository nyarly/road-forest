require 'road-forest'

module RoadForest::RDF
  class SourceRigor
    require 'road-forest/rdf/source-rigor/investigator'
    require 'road-forest/rdf/source-rigor/credence'

    class << self
      def simple
        rigor = self.new
        rigor.policy_list(:must_local, :may_local)
        rigor.investigator_list(:null)
        rigor
      end

      def http
        rigor = self.new
        rigor.policy_list(:may_subject, :any) #XXX
        rigor.investigator_list(:http, :null)
        rigor
      end
    end

    def initialize
      @investigators = []
      @investigation_limit = 3
      @credence_policies = []
    end

    attr_accessor :graph_transfer, :investigators, :investigation_limit, :credence_policies

    def policy_list(*names)
      self.credence_policies = names.map do |name|
        Credence.policy(name)
      end
    end

    def investigator_list(*names)
      self.investigators = names.map do |name|
        Investigator[name].new
      end
    end
  end
end
