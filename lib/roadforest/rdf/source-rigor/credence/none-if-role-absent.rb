class RoadForest::RDF::SourceRigor
  module Credence
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
