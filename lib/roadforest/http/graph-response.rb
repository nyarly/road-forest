module RoadForest
  module HTTP
    class BaseResponse
      attr_reader :url, :response

      def initialize(url, response)
        @url, @response = url, response
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
