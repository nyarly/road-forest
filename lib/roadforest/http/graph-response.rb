module RoadForest
  module HTTP
    class BaseResponse
      attr_reader :request, :response

      def initialize(request, response)
        @request, @response = request, response
      end

      def url
        request.url
      end

      def etag
        response.etag
      end

      def status
        response.status
      end

      def raw_body
        response.body
      end
    end

    class UnparseableResponse < BaseResponse
    end

    class GraphResponse < BaseResponse
      attr_accessor :graph
    end
  end
end
