require 'road-forest/remote-host'
require 'addressable'

module RoadForest
  module TestSupport
    class RemoteHost < ::RoadForest::RemoteHost
      def initialize(app)
        @app = app
        super("http://road-forest.test-domain.com")
      end

      def build_graph_manager
        manager = GraphManager.new
        manager.default_query_manager = QueryHandler[:http]
        manager.http_client = HTTPClient.new(@app, @url)
      end
    end

    class HTTPClient
      def initialize(app, url)
        @app = app
        @default_url = url
        @exchanges = []
      end

      def do_request(method, uri)
        uri = Addressable::URI.parse(uri)
        uri.host = @default_url unless uri.schema == "https" #XXX

        exchange = Exchange.new

        exchange.method = method
        exchange.uri = uri
        exchange.dispatcher = @app.dispatcher

        @exchanges << exchange

        exchange.header('Host', [uri.host, uri.port].compact.join(':'))
        exchange.header('Accept', '*/*')

        yield exchange if block_given?

        exchange.do_request

        document = Document.new
        document.content_type = exchange.response.headers["Content-Type"]
        document.code = exchange.response.code
        document.body_string = exchange.response.body

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

        def headers(hash)
          hash.each do |key, value|
            header(key, value)
          end
        end

        def query_param(name, value)
          @query_params[name] = value
        end

        def query_params(hash)
          hash.each do |key, value|
            query_param(key, value)
          end
        end

        def do_request
          self.uri = Addressable::URI.parse(uri)
          uri.query_values = uri.query_values.merge(query_params)


          @req = Webmachine::Request.new(method, uri, headers, body)
          @res = Webmachine::Response.new

          dispatcher.dispatch(req, res)

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
