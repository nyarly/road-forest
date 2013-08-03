module RoadForest
  module HTTP
    class GraphResponse
      attr_accessor :graph
      attr_reader :request, :response

      def initialize(request, response, graph)
        @request, @response, @graph = request, response, graph
      end

      def url
        request.url
      end

      def status
        response.status
      end
    end
  end
end
