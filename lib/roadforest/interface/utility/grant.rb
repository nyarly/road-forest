module RoadForest
  module Utility
    class Grant
      def path_params
        [ :grant_name ]
      end

      def required_grants
        #except in the unlikely case that a grant hashes to "NSG"
        [ params[:grant_name] || "no_such_grant" ]
      end
    end
  end
end
