require 'rdf'
require 'road-forest/rdf/graph-focus'
require 'road-forest/rdf/vocabulary'
require 'road-forest/rdf/normalization'

require 'road-forest/rdf/resource-query'
require 'road-forest/rdf/resource-pattern'

module RoadForest::RDF
  class GraphStore
    include Normalization

    #The interface supported by ::RDF::Graph
    include ::RDF::Countable
    include ::RDF::Durable
    include ::RDF::Enumerable
    include ::RDF::Mutable
    include ::RDF::Queryable
    include ::RDF::Resource

    attr_reader :repository, :current_impulse, :local_context_node
    attr_accessor :debug_io, :http_client
    attr_accessor :source_rigor

    def initialize(repo = nil)
      @repository = repo || RDF::Repository.new
      @debug_io = nil
      @local_context_node = RDF::Node.new(:local)
      @source_rigor = nil
      next_impulse
      yield self if block_given?
    end

    def next_impulse
      return if !@current_impulse.nil? and raw_quiet_impulse?
      #mark ended?
      #chain impulses?
      @current_impulse = RDF::Node.new
      repository.insert(normalize_statement(@current_impulse, [:dc, 'type'], [:rf, 'Impulse'], nil))
      repository.insert(normalize_statement(@current_impulse, [:rf, 'begunAt'], Time.now, nil))
    end

    def quiet_impulse?
      raw_quiet_impulse?
    end

    def raw_quiet_impulse?
      repository.query([nil, nil, @current_impulse, false]).to_a.empty?
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

    def named_graph(context)
      ::RDF::Graph.new(context, :data => repository)
    end

    def named_list(context, values = nil)
      ::RDF::List.new(nil, named_graph(context), values)
    end

    def create_list(values = nil)
      named_list(local_context_node, values)
    end

    def insert_document(document)
      #puts; puts "#{__FILE__}:#{__LINE__} => #{(document).inspect}"
      #puts document.body_string
      reader = RDF::Reader.for(:content_type => document.content_type) do
        sample = document.body.read(1000)
        document.body.rewind
        sample
      end.new(document.body, :base_uri => document.root_url) #consider :processor_graph
      insert_reader(document.source, reader)
    end

    def insert_reader(context, reader)
      #puts; puts "#{__FILE__}:#{__LINE__} => #{(context).inspect}"
      context = normalize_context(context)
      delete_statements(:context => context)
      reader.each_statement do |statement|
        statement.context = context
        record_statement(statement)
      end
      #puts; puts "#{__FILE__}:#{__LINE__} => \n#{(graph_dump(:nquads))}"
    end

    def insert_graph(context, graph)
      context = normalize_context(context)
      delete_statements(:context => context)
      graph.each_statement do |statement|
        statement.context = context
        record_statement(statement)
      end
    end

    def add_statement(*args)
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

    def insert_statement(statement)
      repository.insert(statement)

      repository.delete([statement.context, expand_curie([:rf, "impulse"]), nil])
      repository.insert(normalize_statement(statement.context, [:rf, "impulse"], current_impulse, nil))
    end
    alias record_statement insert_statement

    def delete_statement(statement)
      repository.query(statement) do |statement|
        next if statement.context.nil?
        repository.delete(statement)
      end
    end

    def replace(original, statement)
      unless original == statement
        repository.delete(original)
        repository.insert(statement)
      end
    end

    #XXX Needs removal
    def start(subject)
      step = GraphFocus.new
      step.subject = normalize_resource(subject)
      step.root_url = step.subject
      step.graph_store = self
      step.source_rigor = source_rigor
      return step
    end

    def each_statement(context=nil, &block)
      query = {}
      unless context.nil?
        query[:context] = context
      end

      @repository.query(query) do |statement|
        yield statement
      end
    end

    def durable?
      @repository.durable?
    end

    #XXX Credence? Default context?
    def each(&block)
      if @repository.respond_to?(:query)
        @repository.query(:context => false, &block)
      elsif @repository.respond_to?(:each)
        @repository.each(&block)
      else
        @repository.to_a.each(&block)
      end
    end

    #XXX Needed, maybe, if we need to handle constant patterns
    #def include?(statement)
    #end

    def context_variable
      @context_variable ||= RDF::Query::Variable.new(:context)
    end

    def query_execute(query, &block)
      #XXX Weird edge case of GM getting queried with a vanilla RDF::Query...
      #needs tests, thought
      query = ResourceQuery.from(query)
      query.execute(self).filter do |solution|
        solution.respond_to?(:context) and not solution.context.nil?
      end.each(&block)
    end

    def query_pattern(pattern, &block)
      case pattern
      when ResourcePattern
        pattern.execute(@repository, {}, :context_roles => {:local => local_context_node}) do |statement|
          next if statement.context.nil?
          yield statement if block_given?
        end
      else
        pattern.execute(@repository, {}) do |statement|
          next if statement.context.nil?
          yield statement if block_given?
        end
      end
    end

    def unnamed_graph
      ::RDF::Graph.new(nil, :data => @repository)
    end

  end
end
