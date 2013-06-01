module RoadForest
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

  #The results of processing an RDF update - could include a new graph, or a
  #different resource (url) to look at
  class Results
    attr_accessor :graph, :subject_resource

    def initialize(subject=nil, graph=nil)
      @graph, @subject_resource = graph, subject
      yield self if block_given?
    end

    def start_graph(resource)
      @graph ||= RDF::GraphManager.new
      focus = @graph.start(resource)
      yield focus if block_given?
      return focus
    end

    def absolutize(root_uri)
      @graph.each_statement(:local) do |statement|
        original = statement.dup
        if ::RDF::URI === statement.subject and statement.subject.relative?
          statement.subject = root_uri.join(statement.subject)
        end

        if statement.predicate.relative?
          statement.predicate = root_uri.join(statement.predicate)
        end

        if ::RDF::URI === statement.object and statement.object.relative?
          statement.object = root_uri.join(statement.object)
        end

        if statement != original
          @graph.replace(original, statement)
        end
      end
    end
  end
end
