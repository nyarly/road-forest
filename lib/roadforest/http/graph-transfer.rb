require 'roadforest/http/message'
require 'roadforest/http/graph-response'
require 'roadforest/content-handling/engine'

module RoadForest
  module HTTP
    class GraphTransfer
      attr_accessor :http_client
      attr_writer :type_handling

      def initialize
        @type_preferences = Hash.new{|h,k| k.nil? ? "*/*" : h[nil]}
      end

      def type_handling
        @type_handling ||= ContentHandling::Engine.default
      end

      def put(url, graph)
        make_request("PUT", url, graph)
      end

      def get(url)
        make_request("GET", url)
      end

      def post(url, graph)
        make_request("POST", url, graph)
      end

      def make_request(method, url, graph=nil)
        method = method.to_s.upcase

        validate(method, url, graph)

        request = setup_request(method, url)

        response = send_request(request, graph)

        return build_response(request, response)
      end

      def validate(method, url, graph)
        case method
        when "GET", "HEAD", "DELETE"
          raise "Method #{method} requires an empty body" unless graph.nil?
        when "POST", "PATCH", "PUT"
          raise "Method #{method} requires a body" if graph.nil?
        #when "OPTION", "TRACE" #Need to put verbs where they go
        else
          raise "Unrecognized method: #{method}"
        end
      end

      def best_type_for(url)
        return @type_preferences[url]
      end

      def setup_request(method, url)
        request = Request.new(method, url)
        request.headers["Accept"] = type_handling.parsers.types.accept_header
        request
      end

      def select_renderer(url)
      end

      def record_accept_header(url, types)
        return if types.nil? or types.empty?
        @type_preferences[nil] = types
        @type_preferences[url] = types
      end

      def render_graph(graph, request)
        return unless request.needs_body?

        content_type = best_type_for(request.url)
        renderer = type_handling.choose_renderer(content_type)
        request.headers["Content-Type"] = renderer.content_type_header
        request.body_string = renderer.from_graph(request.url, graph)
      end

      class Retryable < StandardError; end

      def send_request(request, graph)
        retry_limit ||= 5
        render_graph(graph, request)

        #puts; puts "#{__FILE__}:#{__LINE__} => \n#{(request).inspect}"
        response = http_client.do_request(request)
        #puts; puts "#{__FILE__}:#{__LINE__} => \n#{(response).inspect}"
        case response.status
        when 415 #Type not accepted
          record_accept_header(request.url, response.headers["Accept"])
          raise Retryable
        end
        return response
      rescue Retryable
        raise unless (retry_limit -= 1) > 0
        retry
      end

      def parse_response(base_uri, response)
        parser = type_handling.choose_parser(response.headers["Content-Type"])
        parser.to_graph(base_uri, response.body_string)
      end

      def build_response(request, response)
        graph = parse_response(request.url, response)
        return GraphResponse.new(request, response, graph)
      end
    end
  end
end
