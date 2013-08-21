require 'addressable/uri'
require 'excon'
require 'roadforest/http/message'
module RoadForest
  module HTTP
    class ExconAdapter
      def initialize(url)
        @root_url = Addressable::URI.parse(url)
        @connections = Hash.new{|h,k| h[k] = build_site_connection(k)}
        @connection_defaults = {}
      end
      attr_reader :connection_defaults

      def build_site_connection(site)
        Excon.new(site.to_s, @connection_defaults)
      end

      def site_connection(uri)
        uri = Addressable::URI.parse(uri)
        @connections[uri.normalized_site]
      end

      def do_request(request)
        uri = @root_url.join(request.url)

        connection = site_connection(uri)
        excon_response = connection.request(
          :method => request.method,
          :path => uri.path,
          :headers => request.headers,
          :body => request.body
        )

        response = HTTP::Response.new
        if excon_response.body.is_a? String
          response.body_string = excon_response.body
        else
          response.body = excon_response.body
        end
        response.headers = excon_response.headers
        response.status = excon_response.status

        return response
      end
    end
  end
end
