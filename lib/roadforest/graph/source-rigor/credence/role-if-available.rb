class RoadForest::Graph::SourceRigor
  module Credence
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
  end
end
