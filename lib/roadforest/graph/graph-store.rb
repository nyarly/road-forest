require 'rdf'
require 'roadforest/debug'
require 'roadforest/graph/vocabulary'
require 'roadforest/graph/normalization'

require 'roadforest/source-rigor/resource-query'
require 'roadforest/source-rigor/resource-pattern'

module RoadForest::Graph
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
    attr_accessor :debug_io

    def initialize(repo = nil)
      @repository = repo || RDF::Repository.new
      @local_context_node = RDF::Node.new(:local)
      @debug_io = nil
      force_impulse
      yield self if block_given?
    end

    def force_impulse
      @current_impulse = RDF::Node.new
      repository.insert(normalize_statement(@current_impulse, [:rdf, 'type'], [:rf, 'Impulse'], nil))
      repository.insert(normalize_statement(@current_impulse, [:rf, 'begunAt'], Time.now, nil))
    end

    def next_impulse
      return if quiet_impulse?
      force_impulse
      #mark ended?
      #chain impulses?
    end

    def quiet_impulse?
      repository.query([nil, nil, @current_impulse, false]).to_a.empty?
    end
    alias raw_quiet_impulse? quiet_impulse?

    def reader_for(content_type, repository)
      RDF::Reader.for(content_type)
    end

    def debug(message)
      io = @debug_io || RoadForest.debug_io
      return if io.nil?
      io.puts(message)
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
    alias insert_graph insert_reader

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
      #puts "\n#{__FILE__}:#{__LINE__} => #{[self.object_id,
      #statement].inspect}"
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

    def each_statement(context=nil, &block)
      query = {}
      unless context.nil?
        query[:context] = context
      end

      @repository.query(query) do |statement|
        next if statement.context.nil?
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
      query = RoadForest::SourceRigor::ResourceQuery.from(query)
      query.execute(self).filter do |solution|
        solution.respond_to?(:context) and not solution.context.nil?
      end.each(&block)
    end

    def query_pattern(pattern, &block)
      case pattern
      when RoadForest::SourceRigor::ResourcePattern
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
