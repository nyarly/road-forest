module RoadForest
  class TraceFormatter
    DECISION_NAMES = {
      :b13 => "Service available?",
      :b12 => "Known method?",
      :b11 => "URI too long?",
      :b10 => "Method allowed?",
      :b9 => "Content-MD5 present?",
      :b9a => "Content-MD5 valid?",
      :b9b => "Malformed?",
      :b8 => "Authorized?",
      :b7 => "Forbidden?",
      :b6 => "Okay Content-* Headers?",
      :b5 => "Known Content-Type?",
      :b4 => "Req Entity Too Large?",
      :b3 => "OPTIONS?",
      :c3 => "Accept exists?",
      :c4 => "Acceptable media type available?",
      :d4 => "Accept-Language exists?",
      :d5 => "Acceptable language available?",
      :e5 => "Accept-Charset exists?",
      :e6 => "Acceptable Charset available?",
      :f6 => "Accept-Encoding exists? (also, set content-type header here, now that charset is chosen)",
      :f7 => "Acceptable encoding available?",
      :g7 => "Resource exists?",
      :g8 => "If-Match exists?",
      :g9 => "If-Match: * exists?",
      :g11 => "ETag in If-Match",
      :h7 => "If-Match exists?",
      :h10 => "If-Unmodified-Since exists?",
      :h12 => "Last-Modified > I-UM-S?",
      :i4 => "Moved permanently? (apply PUT to different URI)",
      :i7 => "PUT?",
      :i12 => "If-none-match exists?",
      :i13 => "If-none-match: * exists?",
      :j18 => "GET or HEAD?",
      :k5 => "Moved permanently?",
      :k7 => "Previously existed?",
      :k13 => "Etag in if-none-match?",
      :l5 => "Moved temporarily?",
      :l7 => "POST?",
      :l13 => "If-Modified-Since exists?",
      :l15 => "IMS > Now?",
      :l17 => "Last-Modified > IMS?",
      :m5 => "POST?",
      :m7 => "Server allows POST to missing resource?",
      :m16 => "DELETE?",
      :m20 => "DELETE enacted immediately? (Also where DELETE is forced.)",
      :m20b => "Did the DELETE complete?",
      :n5 => "Server allows POST to missing resource?",
      :n11 => "Redirect?",
      :n16 => "POST?",
      :o14 => "Conflict?",
      :o16 => "PUT?",
      :o18 => "Multiple representations? Also where body generation for GET and HEAD is done.",
      :o18b => "Multiple choices?",
      :o20 => "Response includes an entity?",
      :p3 => "Conflict?",
      :p11 => "New resource?",
    }

    def initialize(trace)
      @trace = trace
    end

    def to_s
      Grouper.new(@trace).to_a.join("\n")
    end

    class Grouper
      include Enumerable

      def initialize(trace)
        @trace = trace
      end

      def format_attempt(attempt)
        unless attempt.length == 2 and
          attempt[0][:type] == :attempt and
          attempt[1][:type] == :result
          raise "Can't format attempt: #{attempt.inspect}"
        end
        name= attempt[0][:name]
        source= attempt[0][:source]
        result= attempt[1][:value]

        if source.nil?
          "  #{name} => #{result.inspect}"
        else
          "\n  #{name}\n  #{source}\n    => #{result.inspect}"
        end
      end

      def format_request(request)
        "\nRequest:\n  #{request[:method]} #{request[:path]}\n#{request[:headers].map do |name, value|
          "  #{name}: #{value}"
        end.join("\n")}#{request[:body].empty? ? "" : "\n\n  #{request[:body]}"}\n.\n"
      end

      def format_response(response)
        "\nResponse:\n  #{response[:code]}\n#{response[:headers].map do |name, value|
          "  #{name}: #{value}"
        end.join("\n")}#{response[:body].empty? ? "" : "\n\n  #{response[:body]}"}\n.\n"
      end

      def format_decision(item)
        "\nDecision: #{DECISION_NAMES[item[:decision]]} (#{item[:decision]})"
      end

      def each
        enum = @trace.each

        group = []
        loop do
          begin
            item = enum.next
            case item[:type]
            when :request
              yield format_request(item)
            when :response
              yield format_response(item)
            when :attempt
              group << item
            when :result
              group << item
              yield format_attempt(group)
              group = []
            when :decision
              yield format_decision(item)
            else
              raise "Don't know trace entry type: #{item.inspect}"
            end
          rescue StopIteration
            break
          end
        end
      end
    end
  end
end
