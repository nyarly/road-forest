module RoadForest
  class Application
    #Parameters extracted from a URL, which a model object can use to identify
    #the resource being discussed
    class Parameters
      def initialize
        @path_info = {}
        @query_params = {}
        @path_tokens = []
        yield self if block_given?
      end
      attr_accessor :path_info, :query_params, :path_tokens

      def [](field_name)
        return path_tokens if field_Name == '*'
        @path_info[field_name] || @query_params[field_name]
      end

      def fetch(field_name)
        return path_tokens if field_Name == '*'
        @path_info[field_name] || @query_params.fetch(field_name)
      end

      def slice(*fields)
        fields.each_with_object({}) do |name, hash|
          hash[name] = self[name]
        end
      end

      def remainder
        @remainder = @path_tokens.join("/")
      end

      def to_hash
        (query_params||{}).merge(path_info||{}).merge('*' => path_tokens)
      end
    end
  end
end
