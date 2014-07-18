require 'roadforest/interface/rdf'

module RoadForest
  module Utility
    class GrantList < Interface::RDF
      def self.path_params
        [ :username ]
      end

      def required_grants(method)
        if method == "GET"
          services.authz.build_grants do |grants|
            grants.add(:is, :name => params[:username])
            grants.add(:admin)
          end
        else
          super
        end
      end

      def new_graph(focus)
        focus.add_list(:az, :grants) do |list|
          services.authz.policy.build_grants(entity).list.each do |grant|
            list << grant
          end
        end
      end
    end
  end
end
