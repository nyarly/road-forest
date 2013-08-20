require 'addressable/uri'
require 'roadforest/test-support/dispatcher-facade'
module RoadForest
  module TestSupport
    class HTTPClient
      def initialize(app, url)
        @app = app
        @default_url = Addressable::URI.parse(url)
        @exchanges = []
        @dispatcher = DispatcherFacade.new(@app.dispatcher)
      end
      attr_reader :exchanges

      def inspect
        "#<#{self.class.name}:#{"%0xd" % object_id} #{exchanges.length} exchanges>"
      end

      def do_request(request)
        uri = request.url

        uri = Addressable::URI.parse(uri)
        uri = @default_url.join(uri)

        exchange = Exchange.new

        exchange.method = request.method
        exchange.uri = uri
        exchange.body = request.body
        exchange.dispatcher = @dispatcher

        @exchanges << exchange

        exchange.header('Host', [uri.host, uri.port].compact.join(':'))
        exchange.header('Accept', '*/*')
        request.headers.each do |name, value|
          exchange.header(name, value)
        end

        yield exchange if block_given?

        #puts; puts "#{__FILE__}:#{__LINE__} => #{(request).inspect}"

        exchange.do_request

        response = HTTP::Response.new
        response.headers = exchange.response.headers.dup
        response.status = exchange.response.code
        response.body_string = exchange.response.body

        #puts; puts "#{__FILE__}:#{__LINE__} => #{(response).inspect}"
        return response
      end

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


          @req = Webmachine::Request.new(method, uri, headers, RequestBody.new(body))
          @res = Webmachine::Response.new

          dispatcher.dispatch(@req, @res)

          return @res
        end

        class RequestBody
          # @return the request from Mongrel

          # @param request the request from Mongrel
          def initialize(body)
            @raw_body = body
          end

          def body
            @body =
              case @raw_body
              when IO, StringIO
                @raw_body.rewind
                @raw_body.read
              when String
                @raw_body
              else
                raise "Can't handle body type: #{@raw_body.class}"
              end

          end

          # @return [String] the request body as a string
          def to_s
            body
          end

          # @yield [chunk]
          # @yieldparam [String] chunk a chunk of the request body
          def each(&block)
            yield(body)
          end
        end # class RequestBody

        private
        def webmachine_test_error(msg)
          raise Webmachine::Test::Error.new(msg)
        end
      end
    end
  end
end
