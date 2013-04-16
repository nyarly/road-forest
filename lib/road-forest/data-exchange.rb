module RoadForest
  #Parameters extracted from a URL, which a model object can use to identify
  #the resource being discussed
  class Parameters
    def initialize
      @path_info = {}
      @get_params = {}
      @remainder = []
    end
    attr_accessor :path_info, :get_params, :remainder

    def [](field_name)
      @path_info[field_name] || @get_params[field_name]
    end

    def fetch(field_name)
      @path_info[field_name] || @get_params.fetch(field_name)
    end

    def slice(*fields)
      fields.each_with_object({}) do |name, hash|
        hash[name] = self[name]
      end
    end

    def to_hash
      @get_params.merge(@path_info).merge('*' => @remainder)
    end
  end

  #The results of processing an RDF update - could include a new graph, or a
  #different resource (url) to look at
  class Result
    attr_accessor :graph, :subject_resource

    def initialize(subject=nil, graph=nil)
      @graph, @subject_resource = graph, subject
    end
  end
end
