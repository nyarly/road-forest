require 'rdf/xsd'
#require 'rdf/spec/writer'
require 'rdf/turtle'
require 'rdf-matchers'
require 'rdf'

require 'roadforest/content-handling/type-handlers/rdfa-writer'
require 'roadforest/rdf/vocabulary'
require 'roadforest/content-handling/type-handlers/rdfa-writer/render-engine'
require 'cgi'

class EX < RDF::Vocabulary("http://example/"); end

describe RoadForest::MediaType::RDFaWriter, :vcr => {} do
  Af = RoadForest::RDF::Af
  # Heuristically detect the input stream
  def detect_format(stream)
    # Got to look into the file to see
    if stream.is_a?(IO) || stream.is_a?(StringIO)
      stream.rewind
      string = stream.read(1000)
      stream.rewind
    else
      string = stream.to_s
    end
    case string
    when /<html/i   then RDF::RDFa::Reader
    when /@prefix/i then RDF::Turtle::Reader
    else                 RDF::NTriples::Reader
    end
  end

  def parse(input, options = {})
    reader_class = RDF::Reader.for(options[:format]) if options[:format]
    reader_class ||= options.fetch(:reader, RDF::Reader.for(detect_format(input)))

    graph = RDF::Repository.new
    reader_class.new(input, options).each do |statement|
      graph << statement
    end
    graph
  end

  before(:all) do
    @valise = Valise.define do
      ro up_to("spec") + "../lib/roadforest"
    end

    @tilt_cache = ::Tilt::Cache.new
  end

  # Serialize  @graph to a string and compare against regexps
  def serialize(options = {})

    options = {:debug => debug, :standard_prefixes => true}.merge(options)
    base_uri =
      if options[:base_uri]
        RDF::URI(options[:base_uri])
      else
        nil
      end

    templates = RoadForest::MediaType::RDFaWriter::TemplateHandler.new
    templates.valise = @valise
    templates.template_cache = @tilt_cache
    templates.style_name = options[:haml]
    templates.haml_options = options[:haml_options]

    engine = RoadForest::MediaType::RDFaWriter::RenderEngine.new(@graph, options[:debug]) do |engine|
      engine.template_handler = templates
      engine.base_uri = base_uri
      engine.lang = options[:lang]
      engine.standard_prefixes = options[:standard_prefixes]
      engine.top_classes = options[:top_classes] || [RDF::RDFS.Class]
      engine.predicate_order = options[:predicate_order] || [RDF.type, RDF::RDFS.label, RDF::DC.title]
      engine.heading_predicates = options[:heading_predicates] || [RDF::RDFS.label, RDF::DC.title]
    end

    engine.prefixes.merge! options[:prefixes] unless options[:prefixes].nil?

    # Generate document
    result = engine.render_document

    puts CGI.escapeHTML(result) if $verbose
    result
  end

  before(:each) do
    @graph = RDF::Repository.new
  end

  let :debug do
    []
  end

  #include RDF_Writer

  describe "#buffer" do
    context "an affordanced graph" do
      #Needed tests
      #  3 levels nesting of subject pred subject pred subject (tricky in terms
      #  of RDFPOST repetition) Each subject needs literal terms
      #
      #Non-afforded subject, property with afforded subject
      #  (Currently, forms are only produced by document)
      #
      #Produce www-form-encoded response based on the form, parse with RDFPOST,
      #confirm identical (or close, b/c forms etc) to base graph. Capybara?
      #Webmachine?


      let :base_graph do
        RDF::Repository.new.tap do |graph|
          graph << [EX.a, EX.b, "foo"]
        end
      end

      let :affordances do
        aff = ::RDF::Node.new(:aff)
        payload = ::RDF::Node.new(:payload_for_a)
        b_param = ::RDF::Node.new(:b_param)

        RDF::Repository.new.tap do |graph|
          graph << [EX.a, EX.b, "foo"]
          graph << [aff, ::RDF.type, Af.Update]
          graph << [aff, Af.target, EX.a]
          graph << [aff, Af.payload, payload]
          graph << [EX.a, EX.b, b_param, payload]
          graph << [b_param, ::RDF.type, Af.Parameter, payload]
        end
      end

      subject do
        base_graph.each_statement do |stmt|
          @graph << stmt
        end

        affordances.each_statement do |stmt|
          @graph << stmt
        end

        serialize(:haml_options => {:ugly => false})
      end

      let :put_uri do
        EX.a.join("put").to_s
      end

      it { should have_xpath('//form/@action', put_uri) }
      it { should have_xpath("//form[@action='#{put_uri}']/@method", "POST") }
      it { should have_xpath("//form[@action='#{put_uri}']/input[@type='hidden']/@name", "rdf") }

      it "should parse base to base_graph" do
        parse(subject, :format => :rdfa).should be_equivalent_graph(base_graph, :trace => debug)
      end
    end
  end
end
