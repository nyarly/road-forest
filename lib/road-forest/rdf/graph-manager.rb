require 'rdf'
require 'road-forest/rdf/graph-focus'
require 'road-forest/rdf/vocabulary'
require 'road-forest/rdf/normalization'

require 'road-forest/rdf/credence'
require 'road-forest/rdf/credible-results'
require 'road-forest/rdf/investigator'

require 'road-forest/rdf/resource-query'
require 'road-forest/rdf/resource-pattern'


module RoadForest::RDF
  class ContextFascade
    include ::RDF::Countable
    include ::RDF::Enumerable
    include ::RDF::Queryable

    def initialize(manager, resource, skepticism)
      @manager, @resource, @skepticism = manager, resource, skepticism
    end

    def query_execute(query, &block)
      ResourceQuery.from(query, @resource, @skepticism).execute(@manager, &block)
    end

    def query_pattern(pattern, &block)
      ResourcePattern.from(query, {:context_roles => {:subject => @resource}}).execute(@manager, &block)
    end
  end

  class SourceSkepticism
    class << self
      def simple
        skeptic = self.new
        skeptic.policy_list(:must_local, :may_local)
        skeptic.investigator_list(:null)
        skeptic
      end

      def http
        skeptic = self.new
        skeptic.policy_list(:may_subject, :any) #XXX
        skeptic.investigator_list(:http, :null)
        skeptic
      end
    end

    def initialize
      @investigators = []
      @investigation_limit = 3
      @credence_policies = []
    end

    attr_accessor :investigators, :investigation_limit, :credence_policies

    def policy_list(*names)
      self.credence_policies = names.map do |name|
        Credence.policy(name)
      end
    end

    def investigator_list(*names)
      self.investigators = names.map do |name|
        Investigator[name].new
      end
    end
  end

  class GraphManager
    include Normalization

    #The interface supported by ::RDF::Graph
      include ::RDF::Countable
      include ::RDF::Durable
    include ::RDF::Enumerable
    include ::RDF::Mutable
    include ::RDF::Queryable
    include ::RDF::Resource

    #nb: methods Graph overrides:
    #[[:graph?
    #[RDF::Resource
    #RDF::Term
    #RDF::Value]]
    #
    #[:empty?
    #[RDF::Enumerable
    #RDF::Countable]]
    #
    #[:contexts
    #[RDF::Enumerable]]
    #
    #[:delete_statement
    #[RDF::Mutable]]
    #
    #[:count
    #[RDF::Queryable
    #
    #RDF::Enumerable
    #RDF::Countable
    #Enumerable]]
    #
    #[:each_graph
    #[RDF::Enumerable]]
    #
    #[:insert_statement
    #[RDF::Mutable
    #RDF::Writable]]
    #
    #[:load!
    #[RDF::Mutable]]
    #
    #[:query_pattern
    #[RDF::Queryable]]
    #
    #[:has_statement?
    #[RDF::Enumerable]]
    #
    #[:durable?
    #[RDF::Durable]]]
    #
    #Notes: currently thinking that the GM should respond to queries of all
    #kinds with credible responses. Clients that want to prevent network access
    #should have an interface to get a "no investigation" GM (with same repo)
    #There's implications for "each" here - since we shouldn't leak less
    #credible statements... and current design separates query handler


    attr_reader :repository, :current_impulse, :local_context_node
    attr_accessor :debug_io, :http_client
    attr_accessor :source_skepticism

    def initialize(repo = nil)
      @repository = repo || RDF::Repository.new
      @debug_io = nil
      @local_context_node = RDF::Node.new(:local)
      @source_skepticism = nil
      next_impulse
      yield self if block_given?
    end

    def next_impulse
      return if !@current_impulse.nil? and quiet_impulse?
      #mark ended?
      #chain impulses?
      @current_impulse = RDF::Node.new
      repository.insert(normalize_statement(@current_impulse, [:dc, 'type'], [:rf, 'Impulse'], nil))
      repository.insert(normalize_statement(@current_impulse, [:rf, 'begunAt'], Time.now, nil))
    end

    def quiet_impulse?
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

    def start(subject)
      step = GraphFocus.new
      step.subject = normalize_resource(subject)
      step.root_url = step.subject
      step.graph_manager = self
      step.source_skepticism = source_skepticism
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
      puts; puts "#{__FILE__}:#{__LINE__} => #{(query.patterns).inspect}"
      query = ResourceQuery.from(query)
      #puts repository_dump(:nquads)
      puts; puts "#{__FILE__}:#{__LINE__} => #{(query.patterns).inspect}"
      query.execute(self).filter do |solution|
        puts; puts "#{__FILE__}:#{__LINE__} => #{(solution).inspect}"
        solution.respond_to?(:context) and not solution.context.nil?
      end.each(&block)
    end

    def query_pattern(pattern, &block)
      case pattern
      when ResourcePattern
        pattern.execute(@repository, {}, :context_roles => {:local => local_context_node}) do |statement|
          yield statement if block_given?
        end
      else
        pattern.execute(@repository, {}) do |statement|
          yield statement if block_given?
        end
      end
    end

    #Queryable::query can call
    #  query_execute (as a strange shorthand - avoid)
    #  query_pattern (if really needed)
    #  each (if query is blank - needs special handling)
    #  include? (if query is constant === "is this statement there?")

    #@param pattern(RDF::Query, RDF::Statement, Array(RDF::Term), Hash
    def infer_context(query)
      subjects = []
      objects = []
      puts; puts "#{__FILE__}:#{__LINE__} => #{(query.class).inspect}"
      case query
      when ContextualQuery
        return query.subject_context
      when RDF::Query
        query.patterns.each do |pattern|
          subjects << pattern.subject
          objects << pattern.object
        end
      when RDF::Statement
        subjects << query.subject
        objects << query.object
      when Array
        subjects << query[0]
        object << query[0]
      when Hash
        subjects << query[:subject]
        objects << query[:object]
      end

      return (subjects + objects).find do |term|
        normalize_context(term).tap{|value| puts "#{__FILE__}:#{__LINE__} => #{({:context => value, :query => query}).inspect}"}
      end
    end

    def unnamed_graph
      ::RDF::Graph.new(nil, :data => @repository)
    end

    def query_unnamed(query)
      query.execute(unnamed_graph)
    end
    end
  end
