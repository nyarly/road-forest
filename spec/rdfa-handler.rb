require 'rdf/xsd'
#require 'rdf/spec/writer'
require 'rdf/turtle'
require 'rdf-matchers'
require 'rdf'

require 'roadforest/content-handling/type-handlers/rdfa-writer'
require 'roadforest/content-handling/type-handlers/rdfa-writer/render-engine'
require 'cgi'

class EX < RDF::Vocabulary("http://example/"); end

describe RoadForest::MediaType::RDFaWriter, :vcr => {} do
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
    context "prefix definitions" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize(:prefixes => {:dc => "http://purl.org/dc/terms/"})
      end

      specify { subject.should have_xpath("/html/@prefix", %r(dc: http://purl.org/dc/terms/), @debug)}
      specify { subject.should have_xpath("/html/@prefix", %r(ex: http://example/), @debug)}
      specify { subject.should have_xpath("/html/@prefix", %r(ex:), @debug)}
    end

    context "plain literal" do
      subject do
        @graph << [EX.a, EX.b, "foo"]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "/html/body/div/@resource" => "ex:a",
        "//div[@class='property']/span[@property]/@property" => "ex:b",
        "//div[@class='property']/span[@property]/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "dc:title" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize(:prefixes => {:dc => RDF::DC.to_s})
      end

      {
        "/html/head/title/text()" => "foo",
        "/html/body/div/@resource" => "ex:a",
        "/html/body/div/h1/@property" => "dc:title",
        "/html/body/div/h1/text()" => "foo",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "typed resources" do
      context "typed resource" do
        subject do
          @graph << [EX.a, RDF.type, EX.Type]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "/html/body/div/@resource" => "ex:a",
          "/html/body/div/@typeof" => "ex:Type",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "resource with two types" do
        subject do
          @graph << [EX.a, RDF.type, EX.t1]
          @graph << [EX.a, RDF.type, EX.t2]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "/html/body/div/@resource" => "ex:a",
          "/html/body/div/@typeof" => "ex:t1 ex:t2",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "languaged tagged literals" do
      context "literal with language and no default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:prefixes => {:dc => "http://purl.org/dc/terms/"})
        end

        {
          "/html/body/div/h1/@property" => "dc:title",
          "/html/body/div/h1/@lang" => "en",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "literal with language and same default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :en)
        end

        {
          "/html/@lang" => "en",
          "/html/body/div/h1/@lang" => false,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "literal with language and different default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :de)
        end

        {
          "/html/@lang" => "de",
          "/html/body/div/h1/@lang" => "en",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "property and rel serialize to different elements" do
        subject do
          @graph << [EX.a, RDF.value, "foo"]
          @graph << [EX.a, RDF.value, EX.b]
          serialize
        end

        {
          "/html/body/div/div/ul/li[@property='rdf:value']/text()" => "foo",
          "/html/body/div/div/ul/li/a[@property='rdf:value']/@href" => EX.b.to_s,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "typed literals" do
      describe "xsd:date" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Date.new("2011-03-18")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "xsd:date",
          "//span[@property]/@content" => "2011-03-18",
          "//span[@property]/text()" => "Friday, 18 March 2011",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "xsd:time" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Time.new("12:34:56")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "xsd:time",
          "//span[@property]/@content" => "12:34:56",
          "//span[@property]/text()" => /12:34:56/,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "xsd:dateTime" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::DateTime.new("2011-03-18T12:34:56")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "xsd:dateTime",
          "//span[@property]/@content" => "2011-03-18T12:34:56",
          "//span[@property]/text()" => /12:34:56 \w+ on Friday, 18 March 2011/,
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "rdf:XMLLiteral" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::XML.new("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time")]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "rdf:XMLLiteral",
          "//span[@property]" => %r(<span [^>]+>E = mc<sup>2</sup>: The Most Urgent Problem of Our Time<\/span>),
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "xsd:string" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => RDF::XSD.string)]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => false, # xsd:string implied in RDF 1.1
          "//span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end

      context "unknown" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => EX.unknown)]
          serialize(:haml_options => {:ugly => false})
        end

        {
          "//span[@property]/@property" => "ex:b",
          "//span[@property]/@datatype" => "ex:unknown",
          "//span[@property]/text()" => "Albert Einstein",
        }.each do |path, value|
          it "returns #{value.inspect} for xpath #{path}" do
            subject.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "multi-valued literals" do
      subject do
        @graph << [EX.a, EX.b, "c"]
        @graph << [EX.a, EX.b, "d"]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//ul/li[1][@property='ex:b']/text()" => "c",
        "//ul/li[2][@property='ex:b']/text()" => "d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//div/@resource" => "ex:a",
        "//a/@property" => "ex:b",
        "//a/@href" => EX.c.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "multi-valued resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.a, EX.b, EX.d]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "//div/@resource" => "ex:a",
        "//ul/li[1]/a[@property='ex:b']/@href" => EX.c.to_s,
        "//ul/li[2]/a[@property='ex:b']/@href" => EX.d.to_s,
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    context "lists" do
      {
        "empty list" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value () .
          ),
          {
            "//div/span[@inlist]/@rel" => 'rdf:value',
            "//div/span[@inlist]/text()" => false,
          }
        ],
        "literal" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value ("Foo") .
          ),
          {
            "//div/span[@inlist]/@property" => 'rdf:value',
            "//div/span[@inlist]/text()" => 'Foo',
          }
        ],
        "IRI" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<foo>) .
          ),
          {
            "//div/a[@inlist]/@property" => 'rdf:value',
            "//div/a[@inlist]/@href" => 'foo',
          }
        ],
        "implicit list with hetrogenious membership" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value ("Foo" <foo>) .
          ),
          {
            "//ul/li[1][@inlist]/@property" => 'rdf:value',
            "//ul/li[1][@inlist]/text()" => 'Foo',
            "//ul/li[2]/a[@inlist]/@property" => 'rdf:value',
            "//ul/li[2]/a[@inlist]/@href" => 'foo',
          }
        ],
        "property with list and literal" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value ("Foo" "Bar"), "Baz" .
          ),
          {
            "//div[@class='property']/span[@property='rdf:value']/text()" => "Baz",
            "//div[@class='property']/ul/li[1][@inlist][@property='rdf:value']/text()" => 'Foo',
            "//div[@class='property']/ul/li[2][@inlist][@property='rdf:value']/text()" => 'Bar',
          }
        ],
        "multiple rel items" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<foo> <bar>) .
          ),
          {
            "//div[@class='property']/ul/li[1]/a[@inlist][@property='rdf:value']/@href" => 'foo',
            "//div[@class='property']/ul/li[2]/a[@inlist][@property='rdf:value']/@href" => 'bar',
          }
        ],
        "multiple collections" => [
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <foo> rdf:value ("Foo"), ("Bar") .
          ),
          {
            "//div[@class='property']/ul/li[1][@inlist][@property='rdf:value']/text()" => 'Foo',
            "//div[@class='property']/ul/li[2][@inlist][@property='rdf:value']/text()" => 'Bar',
          }
        ],
        "issue 14" => [
          %q(
            @base <http://example/> .
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<needs/one> <needs/two> <needs/three>) .
            <needs/one> rdfs:label "one" .
            <needs/three> rdfs:label "three" .
            <needs/two> rdfs:label "two" .
          ),
          {
            "//div[@class='property']/ul/li[1][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" => 'one',
            "//div[@class='property']/ul/li[2][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" => 'two',
            "//div[@class='property']/ul/li[3][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" => 'three',
          }
        ]
      }.each do |test, (input, result)|
        it test do
          pending("Serializing multiple lists") if test == "multiple collections"
          @graph = parse(input, :format => :ttl)
          html = serialize(:haml_options => {:ugly => false})
          result.each do |path, value|
            html.should have_xpath(path, value, @debug)
          end
        end
      end
    end

    context "included resource definitions" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.c, EX.d, EX.e]
        serialize(:haml_options => {:ugly => false})
      end

      {
        "/html/body/div/@resource" => "ex:a",
        "//div[@resource='ex:a']/div[@class='property']/div[@rel]/@rel" => "ex:b",
        "//div[@rel]/@resource" => "ex:c",
        "//div[@rel]/div[@class='property']/a/@href" => EX.e.to_s,
        "//div[@rel]/div[@class='property']/a/@property" => "ex:d",
      }.each do |path, value|
        it "returns #{value.inspect} for xpath #{path}" do
          subject.should have_xpath(path, value, @debug)
        end
      end
    end

    unless ENV['CI'] # Not for continuous integration
      # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
      describe "w3c xhtml testcases" do
        require 'suite_helper'

        # Generate with each template set
        %w{base min distiller}.each do |name, template|
          context "Using #{name} template" do
            Fixtures::TestCase.for_specific("html5", "rdfa1.1", Fixtures::TestCase::Test.required) do |t|
              next if %w(0198 0225 0284 0295 0319 0329).include?(t.num)
              specify "test #{t.num}: #{t.description}" do
                input = t.input("html5", "rdfa1.1")
                @graph = RDF::Repository.load(t.input("html5", "rdfa1.1"))
                result = serialize(:haml => name, :haml_options => {:ugly => true})
                graph2 = parse(result, :format => :rdfa)
                # Need to put this in to avoid problems with added markup
                statements = graph2.query(:object => RDF::URI("http://rdf.kellogg-assoc.com/css/distiller.css")).to_a
                statements.each {|st| graph2.delete(st)}
                #puts graph2.dump(:ttl)
                graph2.should be_equivalent_graph(@graph, :trace => debug.unshift(result.force_encoding("utf-8")).join("\n"))
              end
            end
          end
        end
      end
    end
  end
end
