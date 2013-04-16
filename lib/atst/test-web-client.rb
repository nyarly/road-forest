module ATST
  class TestWebClient
    def initialize
      @patterns = []
    end

    def add_response(regexp)
      builder = TestResponseBuilder.new
      builder.regexp = regexp
      yield builder
      @patterns.unshift builder
      return builder
    end

    def get(uri)
      builder = @patterns.find do |builder|
        builder.regexp =~ uri
      end
      if builder.nil?
        return missing_response(uri)
      else
        return builder.response(uri)
      end
    end

    def missing_response(uri)
      rez = TestResponse.new
      rez.uri = uri
      rez.body_string = "Missing URI in TestWebClient"
      rez.code = 404
      rez
    end

    class TestResponseBuilder
      attr_accessor :content_type, :code, :body, :regexp
      def initialize
        @context_type = "text/html"
        @code = 200
        @body = ""
      end

      def response(uri)
        rez = TestResponse.new
        rez.uri = uri
        rez.body_string = body
        rez.content_type = @content_type
        rez.code = @code
        return rez
      end
    end

    class TestResponse
      attr_accessor :content_type, :code, :uri, :body_string
      def initialize
        @context_type = "text/html"
        @code = 200
        @body_string = ""
      end

      def body_string=(value)
        @body_string = value
        @body = nil
      end

      def body
        return @body ||= StringIO.new(body_string)
      end
    end
  end
end
