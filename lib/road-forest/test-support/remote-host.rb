require 'road-forest/remote-host'
require 'road-forest/rdf/graph-store'
require 'road-forest/rdf/document'
require 'road-forest/test-support/trace-formatter'
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

      def build_graph_store
        RDF::GraphStore.new
      end

      def http_client
        @http_client ||= HTTPClient.new(@app, @url)
      end

      def http_exchanges
        http_client.exchanges
      end
    end


    class FSM < ::Webmachine::Decision::FSM
      def self.trace_on
        unless ancestors.include? Webmachine::Trace::FSM
          include Webmachine::Trace::FSM
        end
        Webmachine::Trace.trace_store = :memory
      end

      def self.dump_trace
        puts trace_dump
      end

      def self.trace_dump
        Webmachine::Trace.traces.map do |trace|
          TraceFormatter.new(Webmachine::Trace.fetch(trace))
        end.join("\n")
      end

      #Um, actually *don't* handle exceptions
      def handle_exceptions
        yield.tap do |result|
          #p result #ok
        end
      end

      def initialize_tracing
        return if self.class.ancestors.include? Webmachine::Trace::FSM
        super
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
        trace_response(response)
      end
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

      def head(url, &block)
        do_request('HEAD', url, &block)
      end

      def get(url, &block)
        do_request('GET', url, &block)
      end

      def post(url, &block)
        do_request('POST', url, &block)
      end

      def put(url, &block)
        do_request('PUT', url, &block)
      end

      def patch(url, &block)
        do_request('PATCH', url, &block)
      end

      def delete(url, &block)
        do_request('DELETE', url, &block)
      end

      def options(url, &block)
        do_request('OPTIONS', url, &block)
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
