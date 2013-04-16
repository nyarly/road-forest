require 'rdf/rdfa'
require 'rdf/microdata'
require 'rdf/turtle'
require 'atst/normalization'

#Cuz it's a walker
module ATST
  class Walker
    include Normalization

    attr_accessor :http_client, :root_url
    attr_reader :graph

    def initialize
      @graph = RDF::Graph.new
      @http_client = nil
      @debug_io = nil
      @root_url = nil
    end

    def reader_for(content_type, graph)
      RDF::Reader.for(content_type)
    end

    def debug(message)
      return if @debug_io.nil?
      @debug_io.puts(message)
    end

    def add_statement(subject, predicate, object, context = nil)
      @graph.insert(normalize_tuple([subject, predicate, object, context]))
    end

    def read(response)
      graph = RDF::Graph.new(response.uri)
      reader_class = RDF::Reader.for(:content_type => response.content_type) do
        sample = response.body.read(1000)
        response.body.rewind
        sample
      end
      reader = reader_class.new(response.body, :base_uri => response.uri, :processor_graph => graph)
      graph.insert(reader.statements)
      return graph
    end

    def merge(graph)
      debug "#{__FILE__}:#{__LINE__} => NEW:\n#{(graph.dump(:turtle))}"
      graph.contexts.each do |context|
        @graph.delete(@graph.query(:context => context))
      end
      @graph.insert(graph.statements)
    end

    def graph_dump(format = :turtle)
      @graph.dump(format)
    end

    def get(uri)
      response = @http_client.get(uri)

      case response.code
      when 200
      when (400..599)
        raise "HTTP error: #{response.code}"
      else
        return
      end

      graph = read(response)

      merge(graph)

      debug "#{__FILE__}:#{__LINE__} => MASTER:\n#{@graph.dump(:turtle)}"
    end

    def start_walk(subject)
      step = Step.new
      step.subject = normalize_resource(subject)
      step.walker = self
      return step
    end

    def query(&block)
      RDF::Query.new(&block).execute(@graph)
    end
  end
end
