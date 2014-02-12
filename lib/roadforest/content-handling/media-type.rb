module RoadForest
  module ContentHandling
    #@credit goes to Sean Cribbs & Ruby Webmachine for the basis of this code
    #
    # Encapsulates a MIME media type, with logic for matching types.
    class MediaType
      # Matches valid media types
      MEDIA_TYPE_REGEX = /^\s*([^;\s]+)\s*((?:;\s*\S+\s*)*)\s*$/

      # Matches sub-type parameters
      PARAMS_REGEX = /;\s*([^;=]+)(?:=([^;=\s]+))?/

      # Creates a new MediaType by parsing an alternate representation.
      # @param [MediaType, String, Array<String,Hash>] obj the raw type
      #   to be parsed
      # @return [MediaType] the parsed media type
      # @raise [ArgumentError] when the type could not be parsed
      def self.parse(*args)
        if args.length == 1
          obj = args.first
        else
          obj = args
        end

        if obj.is_a? MediaType
          obj
        elsif obj.is_a? String and !(match = MEDIA_TYPE_REGEX.match(obj)).nil?
          type, raw_params = *match[1,2]
          params = Hash[raw_params.scan(PARAMS_REGEX)]
          new(type, params)
        elsif Array === obj && String === obj[0] && Hash === obj[1]
          type = parse(obj[0])
          type.params.merge!(obj[1])
          type
        else
          raise ArgumentError, "Invalid media type #{obj.inspect}"
        end
      end

      # @return [String] the MIME media type
      attr_accessor :type

      # @return [Hash] any type parameters, e.g. charset
      attr_accessor :params

      # @param [String] type the main media type, e.g. application/json
      # @param [Hash] params the media type parameters
      def initialize(type, params={})
        @type, @params = type, params
        @quality = (@params.delete('q') || "1.0").to_f
      end

      attr_reader :quality

      # Detects whether the {MediaType} represents an open wildcard
      # type, that is, "*/*" without any {#params}.
      def matches_all?
        @type == "*/*" && @params.empty?
      end

      # @return [true,false] Are these two types strictly equal?
      # @param other the other media type.
      # @see MediaType.parse
      def ==(other)
        other = self.class.parse(other)
        other.type == type && other.params == params
      end

      # Detects whether this {MediaType} matches the other {MediaType},
      # taking into account wildcards. Sub-type parameters are treated
      # strictly.
      # @param [MediaType, String, Array<String,Hash>] other the other type
      # @return [true,false] whether it is an acceptable match
      def exact_match?(other)
        other = self.class.parse(other)
        type_matches?(other) && other.params == params
      end

      # Detects whether the {MediaType} is an acceptable match for the
      # other {MediaType}, taking into account wildcards and satisfying
      # all requested parameters, but allowing this type to have extra
      # specificity.
      # @param [MediaType, String, Array<String,Hash>] other the other type
      # @return [true,false] whether it is an acceptable match
      def match?(other)
        other = self.class.parse(other)
        type_matches?(other) && params_match?(other.params)
      end
      alias =~ match?

      # Detects whether the passed sub-type parameters are all satisfied
      # by this {MediaType}. The receiver is allowed to have other
      # params than the ones specified, but all specified must be equal.
      # @param [Hash] params the requested params
      # @return [true,false] whether it is an acceptable match
      def params_match?(other)
        other.all? do |k,v|
          params[k] == v
        end
      end

      def params_for_header
        params.map {|k,v| ";#{k}#{v ? "=":""}#{v}" }.join("")
      end

      def accept_header
        "#{type};q=#{quality}#{params_for_header}"
      end

      def content_type_header
        "#{type}#{params_for_header}"
      end
      alias to_s content_type_header

      # @return [String] The major type, e.g. "application", "text", "image"
      def major
        @major ||= type.split("/").first
      end

      # @return [String] the minor or sub-type, e.g. "json", "html", "jpeg"
      def minor
        @minor ||= type.split("/").last
      end

      def precedence_index
        [
          @major == "*" ? 0 : 1,
          @minor == "*" ? 0 : 1,
          (@params.keys - %w{q}).length
        ]
      end

      # @param [MediaType] other the other type
      # @return [true,false] whether the main media type is acceptable,
      #   ignoring params and taking into account wildcards
      def type_matches?(other)
        other = self.class.parse(other)
        if ["*", "*/*", type].include?(other.type)
          true
        else
          other.major == major && other.minor == "*"
        end
      end
    end

    class MediaTypeList
      # Given an acceptance list, create a PriorityList from them.
      def self.build(list)
        return list if self === list

        case list
        when Array
        when String
          list = list.split(/\s*,\s*/)
        else
          raise "Cannot build a MediaTypeList from #{list.inspect}"
        end

        new.tap do |plist|
          list.each {|item| plist.add_header_val(item) }
        end
      end

      include Enumerable

      # Creates a {PriorityList}.
      # @see PriorityList::build
      def initialize
        @list = []
      end

      def accept_header
        @list.map(&:accept_header).join(", ")
      end
      alias to_s accept_header

      #Given another MediaTypeList, find the media type that is the best match
      #between them - generally, the idea is to match an Accept header with a
      #local list of provided types
      def best_match_from(other)
        other.max_by do |their_type|
          best_type = self.by_precedence.find do |our_type|
            their_type =~ our_type
          end
          if best_type.nil?
            0
          else
            best_type.quality * their_type.quality
          end
        end
      end

      def matches?(other)
        type = best_match_from(other)
        include?(type) && other.include?(type)
      end

      def by_precedence
        self.sort do |left, right|
          right.precedence_index <=> left.precedence_index
        end.enum_for(:each)
      end

      # Adds an acceptable item with the given priority to the list.
      # @param [Float] q the priority
      # @param [String] choice the acceptable item
      def add(type)
        @list << type
        self
      end

      # Given a raw acceptable value from an acceptance header,
      # parse and add it to the list.
      # @param [String] c the raw acceptable item
      # @see #add
      def add_header_val(type_string)
        add(MediaType.parse(type_string))
      rescue ArgumentError
        raise "Invalid media type"
      end

      # Iterates over the list in priority order, that is, taking
      # into account the order in which items were added as well as
      # their priorities.
      # @yield [q,v]
      # @yieldparam [Float] q the acceptable item's priority
      # @yieldparam [String] v the acceptable item
      def each
        return enum_for(:each) unless block_given?
        @list.each do |item|
          yield item
        end
      end
    end
  end
end
