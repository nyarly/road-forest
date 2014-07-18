module RoadForest
  module Authorization
    class GrantBuilder
      def initialize(cache)
        @cache = cache
        @list = []
      end
      attr_reader :list

      def add(name, params=nil)
        canonical =
          if params.nil?
            [name]
          else
            [name, params.keys.sort.map do |key|
              [key, params[key]]
            end]
          end
        @list << @cache[canonical]
      end
    end
  end
end
