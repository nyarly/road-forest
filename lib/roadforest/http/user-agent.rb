require 'roadforest/http'
require 'roadforest/http/keychain'

module RoadForest
  module HTTP
    class UserAgent
      def initialize(http_client)
        @http_client = http_client
        @trace = nil
        @cache = Hash.new do |cache, url|
          cache[url] = {}
        end
      end

      attr_accessor :http_client, :trace
      attr_reader :cache

      def make_request(method, url, headers = nil, body=nil, retry_limit=5)
        headers ||= {}

        method = method.to_s.upcase

        validate(method, url, headers, body)

        request = setup_request(method, url, headers, body)

        response = send_request(request, retry_limit)

        cache_response(url, response)

        return response
      end

      def setup_request(method, url, headers, body)
        request = Request.new(method, url)
        request.headers.merge!(headers)
        request.body = body
        add_authorization(request)
        add_cache_headers(request)
        request
      end

      def send_request(request, retry_limit=5)
        #Check expires headers on received

        trace_message(request)
        response = http_client.do_request(request)
        trace_message(response)
        case response.status
        when 304 #Not Modified
          response = cache.fetch(request.url).fetch(response.etag)
          trace_message(response)
          return response
        when 401
          #XXX What if challenge matches existing Auth header? i.e. current
          #creds are wrong?
          request.headers["Authorization"] = keychain.challenge_response(request.url, response.headers["WWW-Authenticate"])
          raise Retryable
        end
        return response
      rescue Retryable
        raise unless (retry_limit -= 1) > 0
        retry
      end

      def trace_message(message)
        return unless @trace
        @trace = $stderr unless @trace.respond_to?(:puts)
        @trace.puts message.inspect
      end

      def keychain
        @keychain ||= Keychain.new
      end

      def cache_response(url, response)
        return if response.etag.nil?
        return if response.etag.empty?
        #XXX large bodies
        cache[url][response.etag] = response
      end

      def validate(method, url, headers, body)
        case method
        when "GET", "HEAD", "DELETE"
          raise "Method #{method} requires an empty body" unless body.nil?
        when "POST", "PATCH", "PUT"
          raise "Method #{method} requires a body" if body.nil?
        #when "OPTION", "TRACE" #Need to put verbs where they go
        else
          raise "Unrecognized method: #{method}"
        end
      end

      def add_authorization(request)
        request.headers["Authorization"] = keychain.preemptive_response(request.url)
      end

      def add_cache_headers(request)
        case request.method
        when "GET"
          return unless cache.has_key?(request.url)
          cached = cache[request.url]
          return if cached.empty?
          request.headers["If-None-Match"] = cached.keys.join(", ")
        when "POST", "PUT"
          return unless cache.has_key?(request.url)
          cached = cache[request.url]
          return if cached.empty?
          request.headers["If-Match"] = cached.keys.join(", ")
        end
      end
    end
  end
end
