require 'roadforest/interface/rdf'

module RoadForest
  module Utility
    class Backfill < Interface::RDF
      # A backfill domain is an opaque selector for backfills and their client
      # resources to coordinate with. Use them to partition backfills by the
      # stability of interface, or to group like resources or whatever.
      # Backfill domain names will never be exposed outside of the server.
      def domains
        [:general]
      end

      # Backfill types are used to select within a resource which backfill is
      # being rendered - the defaults are :update and :create to correspond
      # with PUT and POST methods and af:Update and af:Create.
      def types
        [:update, :create]
      end

      def root_for(route, domain, type)
        url = my_url
        url.hash = "#{route.name}-#{type}"
      end

      def new_graph
        graph = ::RDF::Graph.new
        router.each_route do |route|
          interface_class = route.interface_class
          next if interface_class.nil?
          next unless interface_class.respond_to? :backfill_payload

          domains.each do |domain|
            types.each do |type|
              payload_graph = interface_class.backfill_payload(domain, type, root_for(route, domain, type))

              next if payload_graph.nil?

              payload_graph.each_statement do |stmt|
                graph << stmt
              end
            end
          end

        end

        graph
      end

    end
  end
end
