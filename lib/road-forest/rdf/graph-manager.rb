require 'rdf'
require 'road-forest/rdf/graph-focus'
require 'road-forest/rdf/query-handler'
require 'road-forest/rdf/vocabulary'

module RoadForest::RDF
  class GraphManager
    include Normalization

    attr_reader :repository, :current_impulse, :local_context_node
    attr_accessor :default_query_manager, :debug_io, :http_client

    def initialize(repo = nil)
      @repository = repo || RDF::Repository.new
      @debug_io = nil
      @default_query_manager = QueryHandler[:simple]
      @local_context_node = RDF::Node.new(:local)
      next_impulse
    end

    def next_impulse
      return if quiet_impulse?
      #mark ended?
      #chain impulses?
      @current_impulse = RDF::Node.new
      repository.insert(normalize_statement(@current_impulse, [:dc, 'type'], [:rf, 'Impulse'], nil))
      repository.insert(normalize_statement(@current_impulse, [:rf, 'begunAt'], Time.now, nil))
    end

    def quiet_impulse?
      repository.query([nil, nil, @current_impulse, false]).empty?
    end

    #repo cleanup - expired graphs

    def reader_for(content_type, repository)
      RDF::Reader.for(content_type)
    end

    def debug(message)
      return if @debug_io.nil?
      @debug_io.puts(message)
    end

    def repository_dump(format = :turtle)
      repository.dump(format)
    end
    alias graph_dump repository_dump

    def delete_statements(pattern)
      repository.delete(pattern)
    end

    def insert_document(document)
      p document
      puts document.body_string
      reader = RDF::Reader.for(:content_type => document.content_type) do
        sample = document.body.read(1000)
        document.body.rewind
        sample
      end.new(document.body, :base_uri => document.root_url) #consider :processor_graph
      insert_reader(document.source, reader)
    end

    def insert_reader(context, reader)
      puts; puts "#{__FILE__}:#{__LINE__} => #{(context).inspect}"
      context = normalize_resource(context)
      delete_statements(:context => context)
      reader.each_statement do |statement|
        statement.context = context
        record_statement(statement)
      end
      puts; puts "#{__FILE__}:#{__LINE__} => \n#{(graph_dump(:nquads))}"
    end

    def insert_statement(*args)
      case args.length
      when 1
        subject, predicate, object, context = *args.first
      when 2
        triple, context = *args
        subject, predicate, object = *triple
      when 3
        subject, predicate, object = *args
        context = nil
      when 4
        subject, predicate, object, context = *args
      else
        raise ArgumentError, "insert_statement needs some variation of subject, predicate, object, [context]"
      end
      context ||= local_context_node

      record_statement(normalize_statement(subject, predicate, object, context))
    end
    alias add_statement insert_statement

    def replace(original, statement)
      unless original == statement
        repository.delete(original)
        repository.insert(statement)
      end
    end

    def record_statement(statement)
      puts; puts "#{__FILE__}:#{__LINE__} => #{[statement, statement.context].inspect}"
      repository.insert(statement)

      repository.delete([statement.context, expand_curie([:rf, "impulse"]), nil])
      repository.insert(normalize_statement(statement.context, [:rf, "impulse"], current_impulse, nil))
    end

    def start(subject)
      step = GraphFocus.new
      step.subject = normalize_resource(subject)
      step.graph_manager = self
      return step
    end

    def find_statements(pattern)
      @repository.query(pattern).find_all do |statement|
        not statement.context.nil?
      end
    end

    def each_statement(context, &block)
      @repository.query(:context => context) do |statement|
        yield statement
      end
    end

    def query(query)
      context = RDF::Query::Variable.new(:context)
      query.patterns.each do |pattern|
        pattern.context = context
      end
      query.execute(@repository).filter do |solution|
        puts; puts "#{__FILE__}:#{__LINE__} => #{(solution).inspect}"
        not solution.context.nil?
      end.tap{|value| puts "#{__FILE__}:#{__LINE__} => #{{query => value}.inspect}"}
    end

    def query_unnamed(query)
      query.patterns.each do |pattern|
        pattern.context = false
      end
      query.execute(@repository)
    end
  end
end
