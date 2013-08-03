require 'stringio'

module RoadForest
  module HTTP
    class Message
      attr_accessor :body, :headers
      attr_reader :body_string

      def initialize
        @body_string = ""
        @headers = {}
      end

      def body_string=(value)
        @body_string = value
        @body = nil
      end

      def body
        return @body ||= StringIO.new(body_string||"")
      end

      def empty?
        if @body.nil?
          @body_string.nil? || @body_string.empty?
        else
          @body.respond_to?(:size) && @body.size <= 0
        end
      end
    end

    class Request < Message
      attr_accessor :method, :url

      def initialize(method, url)
        super()
        @method, @url = method, url
      end

      def needs_body?
        %w{POST PATCH PUT}.include?(@method)
      end
    end

    class Response < Message
      attr_accessor :status
    end
  end
end
