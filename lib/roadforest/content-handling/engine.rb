require 'roadforest/content-handling/media-type'
require 'roadforest/content-handling/handler-wrap'

module RoadForest
  module ContentHandling
    class UnrecognizedType < ::StandardError; end

    class Engine
      class TypeHandlerList
        def initialize(prefix)
          @prefix = prefix
          @types = MediaTypeList.new
          @handlers = {}
          @type_map = []
          @symbol_lookup = {}
        end
        attr_reader :handlers, :types, :type_map

        def add(handler)
          type = handler.type
          @types.add(type)
          @handlers[type] = handler
          symbol = handler_symbol(type)
          raise "Type collision: #{type} already in #{self.inspect}" if @symbol_lookup.has_key?(symbol)
          @type_map << [type.content_type_header, symbol]
          @symbol_lookup[symbol] = handler
        end

        def handler_symbol(type)
          "#{@prefix}_#{type.accept_header.gsub(/\W/, "_")}".to_sym
        end

        def fetch(symbol, &block)
          @symbol_lookup.fetch(symbol, &block)
        end

        def reset
          @handlers.clear
        end

        def handler_for(type)
          type = MediaType.parse(type)
          @handlers.fetch(type)
        rescue KeyError
          raise UnrecognizedType, "No Content-Type handler for #{type}"
        end
      end

      def initialize
        @renderers = TypeHandlerList.new("provide")
        @parsers = TypeHandlerList.new("accept")
        @type_mapping = {}
      end
      attr_reader :renderers, :parsers

      def add_type(handler, type)
        type = MediaType.parse(type)
        add_parser(handler, type)
        add_renderer(handler, type)
      end
      alias add add_type

      def add_parser(object, type)
        type = MediaType.parse(type)
        wrapper = RoadForest::MediaType::Handlers::Wrap::Parse.new(type, object)
        parsers.add(wrapper)
      end
      alias accept add_parser

      def add_renderer(object, type)
        type = MediaType.parse(type)
        wrapper = RoadForest::MediaType::Handlers::Wrap::Render.new(type, object)
        renderers.add(wrapper)
      end
      alias provide add_renderer

      def fetch(symbol)
        @renderers.fetch(symbol){ @parsers.fetch(symbol) }
      end

      def choose_renderer(header)
        content_type = choose_media_type(renderers.types, header)
        return renderers.handler_for(content_type)
      end

      def each_renderer(&block)
        renderers.handlers.enum_for(:each_pair) unless block_given?
        renderers.handlers.each_pair(&block)
      end

      def choose_parser(header)
        content_type = choose_media_type(parsers.types, header)
        return parsers.handler_for(content_type)
      end

      def each_parser(&block)
        parsers.handlers.enum_for(:each_pair) unless block_given?
        parsers.handlers.each_pair(&block)
      end

      # Given the 'Accept' header and provided types, chooses an
      # appropriate media type.
      def choose_media_type(provided, header)
        return "*/*" if header.nil?
        requested = MediaTypeList.build(header.split(/\s*,\s*/))
        requested.best_match_from(provided)
      end
    end
  end
end
