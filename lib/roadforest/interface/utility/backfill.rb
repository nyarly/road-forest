require 'roadforest/interface/rdf'

module RoadForest
  module Utility
    class Backfill < Interface::RDF
      # A backfill domain is an opaque selector for backfills and their client
      # resources to coordinate with. Use them to partition backfills by the
      # stability of interface, or to group like resources or whatever.
      # Backfill domain names will never be exposed outside of the server.
      def self.domains
        [:general]
      end

      def domains
        self.class.domains
      end

      # Backfill types are used to select within a resource which backfill is
      # being rendered - the defaults are :update and :create to correspond
      # with PUT and POST methods and af:Update and af:Create.
      def self.types
        [:update, :create]
      end

      def types
        self.class.types
      end

      def root_for(name, domain, type)
        my_url + self.class.fragment_for(name, type)
      end

      def self.fragment_for(name, type)
        "##{name}-#{type}"
      end

      def new_graph
        graph = ::RDF::Graph.new
        path_provider.each_name_and_route do |name, route|
          interface_class = route.interface_class
          next if interface_class.nil?
          next unless interface_class.respond_to? :backfill_payload

          domains.each do |domain|
            types.each do |type|
              payload_graph = interface_class.backfill_payload(domain, type, root_for(name, domain, type))

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
