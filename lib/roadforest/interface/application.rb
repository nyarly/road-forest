require 'roadforest/rdf/graph-store'
require 'roadforest/rdf/etagging'
require 'roadforest/rdf/access-manager'
require 'roadforest/rdf/graph-focus'

module RoadForest
  module Interface
    class ProcessingSequenceError < StandardError
    end

    class Application
      def initialize(route_name, params, router, services)
        @route_name = route_name
        @params = params
        @router = router
        @services = services
        @data = nil
        @response_values = {}
      end
      attr_reader :route_name, :params, :services, :data, :router
      attr_reader :response_values

      #@!group Utility methods

      def path_for(route_name = nil, params = nil)
        router.path_for(route_name, params || self.params)
      end

      def url_for(route_name, params = nil)
        Addressable::URI.parse(canonical_host.to_s).join(path_for(route_name, params))
      end

      def interface_for(route_name = nil, params = nil)
        router.interface_for(route_name, params || self.params)
      end

      def canonical_uri
        url_for(route_name, params)
      end

      def my_path
        path_for(route_name, params)
      end

      def my_url
        canonical_uri.to_s
      end

      #@!endgroup

      #@!group Authorization

      def required_grants(method)
        services.authz.build_grants do |grants|
          grants.add(:admin)
        end
      end

      def authorization(method, header)
        required = required_grants(method)
        if required.empty?
          :public
        else
          services.authz.authorization(header, required_grants(method))
        end
      end

      def authentication_challenge
        services.authz.challenge(:realm => "Roadforest")
      end

      #@!endgroup

      def canonical_host
        services.canonical_host
      end

      def reset #XXX remove?
      end

      #group Resource interface

      def exists?
        !data.nil?
      end

      def etag
        nil
      end

      def last_modified
        nil
      end

      def response_location
        @response_values.fetch(:location) do
          raise ProcessingSequenceError, "Location not available until request processed"
        end
      end

      def response_location=(location)
        @response_values[:location] = location
      end

      def response_data
        @response_values.fetch(:data) do
          raise ProcessingSequenceError, "Location not available until request processed"
        end
      end

      def response_data=(data)
        @response_values[:data] = data
      end

      def processed
        [:location, :data].each do |key|
          unless @response_values.has_key?(key)
            @response_values[key] = nil
          end
        end
      end

      def expires
        nil
      end

      def update(data)
        raise NotImplementedError
      end

      def add_child(results)
        raise NotImplementedError
      end

      def retrieve
        raise NotImplementedError
      end
      alias retreive retrieve

      def delete
        false
      end
    end
  end
end
