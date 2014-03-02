require 'stringio'
require 'roadforest'

module RoadForest::Graph
  #Wrapper for text to be parsed into RDF
  class Document
    attr_accessor :content_type, :code, :source, :root_url, :body, :body_string
    def initialize
      @content_type = "text/html"
      @code = 200
      @body_string = ""
    end

    def body_string=(value)
      @body_string = value
      @body = nil
    end

    def body
      return @body ||= StringIO.new(body_string)
    end
  end
end
