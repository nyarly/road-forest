require 'road-forest/remote-host'
require 'road-forest/rdf/graph-manager'
require 'road-forest/rdf/document'
require 'addressable/uri'
require 'webmachine/headers'
require 'webmachine/request'
require 'webmachine/response'
require 'webmachine/decision/flow'

module RoadForest
  module TestSupport
    class RemoteHost < ::RoadForest::RemoteHost
      def initialize(app)
        @app = app
        super(app.canonical_host)
      end

      def build_graph_manager
        manager = RDF::GraphManager.http
        manager.http_client = HTTPClient.new(@app, @url)
        manager
      end

      def http_exchanges
        @graph.http_client.exchanges
      end
    end

    class FSM < ::Webmachine::Decision::FSM
      #Um, actually *don't* handle exceptions
      def handle_exceptions
        yield.tap do |result|
          #p result #ok
        end
      end

      def run
        state = Webmachine::Decision::Flow::START
        trace_request(request)
        loop do
          trace_decision(state)
          result = handle_exceptions { send(state) }
          case result
          when Fixnum # Response code
            respond(result)
            break
          when Symbol # Next state
            state = result
          else # You bwoke it
            raise InvalidResource, t('fsm_broke', :state => state, :result => result.inspect)
          end
        end
      ensure
        trace_response(response)                                                                                                                           end
    end

    class DispatcherFacade < BasicObject
      def initialize(dispatcher)
        @dispatcher = dispatcher
      end

      def method_missing(method, *args, &block)
        @dispatcher.__send__(method, *args, &block)
      end

      def dispatch(request, response)
        if resource = @dispatcher.find_resource(request, response)
          FSM.new(resource, request, response).run
        else
          Webmachine.render_error(404, request, response)
        end
      end
    end

    class HTTPClient
      def initialize(app, url)
        @app = app
        @default_url = url
        @exchanges = []
        @dispatcher = DispatcherFacade.new(@app.dispatcher)
      end
      attr_reader :exchanges

      def do_request(method, uri)
        uri = Addressable::URI.parse(uri)
        uri = @default_url.join(uri)

        exchange = Exchange.new

        exchange.method = method
        exchange.uri = uri
        exchange.dispatcher = @dispatcher

        @exchanges << exchange

        exchange.header('Host', [uri.host, uri.port].compact.join(':'))
        exchange.header('Accept', '*/*')

        yield exchange if block_given?

        exchange.do_request

        document = RDF::Document.new
        document.content_type = exchange.response.headers["Content-Type"]
        document.code = exchange.response.code
        document.body_string = exchange.response.body
        document.source = uri

        return document
      end

      def head(url, &block); do_request('HEAD', url, &block); end
      def get(url, &block); do_request('GET', url, &block); end
      def post(url, &block); do_request('POST', url, &block); end
      def put(url, &block); do_request('PUT', url, &block); end
      def patch(url, &block); do_request('PATCH', url, &block); end
      def delete(url, &block); do_request('DELETE', url, &block); end
      def options(url, &block); do_request('OPTIONS', url, &block); end

      class Exchange
        def initialize
          @uri = nil
          @method = nil
          @headers = Webmachine::Headers.new
          @query_params = {}
          @req = nil
          @res = nil
        end
        attr_accessor :uri, :method, :body, :dispatcher
        attr_reader :headers, :query_params

        # Returns the request object.
        def request
          @req || webmachine_test_error('No request object yet. Issue a request first.')
        end

        # Returns the response object after a request has been made.
        def response
          @res || webmachine_test_error('No response yet. Issue a request first!')
        end

        # Set a single header for the next request.
        def header(name, value)
          @headers[name] = value
        end

        def headers=(hash)
          hash.each do |key, value|
            header(key, value)
          end
        end

        def query_param(name, value)
          @query_params[name] = value
        end

        def query_params=(hash)
          hash.each do |key, value|
            query_param(key, value)
          end
        end

        def do_request
          self.uri = Addressable::URI.parse(uri)
          uri.query_values = (uri.query_values || {}).merge(query_params)


          @req = Webmachine::Request.new(method, uri, headers, body)
          @res = Webmachine::Response.new

          dispatcher.dispatch(@req, @res)

          return @res
        end

        private
        def webmachine_test_error(msg)
          raise Webmachine::Test::Error.new(msg)
        end
      end
    end
  end
end
