require 'rdf'
require 'road-forest/rdf/graph-focus'
require 'road-forest/rdf/vocabulary'

require 'road-forest/rdf/credence'
require 'road-forest/rdf/credible-results'
require 'road-forest/rdf/investigator'


module RoadForest::RDF
  class GraphManager
    include Normalization

    #The interface supported by ::RDF::Graph
    include ::RDF::Countable
    include ::RDF::Durable
    include ::RDF::Enumerable
    include ::RDF::Mutable
    include ::RDF::Queryable
    include ::RDF::Resource

    class << self
      def simple
        self.new do |handler|
          handler.policy_list(:must_local, :may_local)
          handler.investigators = [NullInvestigator.new]
        end
      end

      def http
        self.new do |handler|
          handler.policy_list(:may_subject, :any) #XXX
          handler.investigators = [HTTPInvestigator.new, NullInvestigator.new]
        end
      end
    end

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
    attr_accessor :investigators, :investigation_limit, :credence_policies

    def initialize(repo = nil)
      @investigators = []
      @investigation_limit = 3
      @credence_policies = []
      @repository = repo || RDF::Repository.new
      @debug_io = nil
      @local_context_node = RDF::Node.new(:local)
      next_impulse
      yield self if block_given?
    end

    def policy_list(*names)
      self.credence_policies = names.map do |name|
        Credence.policy(name)
      end
    end

    def context_roles(subject_uri)
      {
        :local => local_context_node,
        :subject => subject_uri
      }
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

    def normalize_context(term)
      term = uri(term)
      term.fragment = nil
      term
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
      return step
    end

    def each_statement(context, &block)
      @repository.query(:context => context) do |statement|
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

    def context_variable
      @context_variable ||= RDF::Query::Variable.new(:context)
    end

    def query_execute(query, &block)
      query.patterns.each do |pattern|
        pattern.context = context_variable
      end
      query.execute(@repository).filter do |solution|
        not solution.context.nil?
      end.each(&block)
    end

    def query_pattern(pattern, &block)
      pattern = pattern.dup
      pattern.context = context_variable
      @repository.query(pattern) do |statement|
        next if statement.context.nil?
        yield statement if block_given?
      end
    end

    def credible_query(subject, query)
      results = QueryResults.new(self, context_roles(subject), query)
      results = check(results)
    end

    def check(results)
      investigators.each do |investigator|
        catch :not_credible do
          contexts = results.contexts
          credence_policies.each do |policy|
            contexts = policy.credible(contexts, results)
            if contexts.empty?
              throw :not_credible
            end
          end
          return results.for_context(contexts.first)
        end
        results = investigator.pursue(results)
      end
      raise NoCredibleResults
    end

    def unnamed_graph
      ::RDF::Graph.new(nil, :data => @repository)
    end

    def query_unnamed(query)
      query.patterns.each do |pattern|
        pattern.context = false
      end
      query.execute(@repository)
    end
  end
end
