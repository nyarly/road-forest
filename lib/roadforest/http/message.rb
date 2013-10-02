
require 'stringio'

module RoadForest
  module HTTP
    class Message
      attr_accessor :headers

      def initialize
        @body_string = ""
        @headers = {}
      end

      def body_string=(value)
        @body_string = value
        @body = nil
      end

      def body=(value)
        @body = value
        @body_string = nil
      end

      def body
        return @body ||= StringIO.new(body_string||"")
      end

      def body_string
        @body_string ||=
          begin
            case @body
            when nil
              nil
            when StringIO
              @body.string
            when IO
              @body.rewind
              @body.read
            else
              raise "Unknown class for body: #{@body.class.name}"
            end
          end
      end

      def inspect
        "#<#{self.class.name}:#{'0x%0xd'%object_id}\n  #{inspection_payload.join("\n  ")}\n>"
      end

      def inspection_payload
        old_pos = body.pos
        body.rewind
        [headers.inspect, body.read]
      ensure
        body.pos = old_pos
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

      def inspect
        "\n" + super
      end

      def needs_body?
        %w{POST PATCH PUT}.include?(@method)
      end

      def inspection_payload
        ["#{method} #{url}"] + super
      end
    end

    class Response < Message
      attr_accessor :status

      def etag
        headers["ETag"]
      end

      def inspection_payload
        [status] + super
      end
    end
  end
end
