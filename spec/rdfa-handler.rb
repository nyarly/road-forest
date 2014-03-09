require 'rdf/xsd'
#require 'rdf/spec/writer'
require 'rdf/turtle'
require 'rdf'

require 'roadforest/type-handlers/rdfa-writer'
require 'roadforest/type-handlers/rdfa-writer/render-engine'
require 'cgi'

class EX < RDF::Vocabulary("http://example.com/"); end

describe RoadForest::TypeHandlers::RDFaWriter, :vcr => {} do
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

    templates = RoadForest::TypeHandlers::RDFaWriter::TemplateHandler.new
    templates.valise = @valise
    templates.template_cache = @tilt_cache
    templates.style_name = options[:haml]
    templates.haml_options = options[:haml_options]

    engine = RoadForest::TypeHandlers::RDFaWriter::RenderEngine.new(@graph, options[:debug]) do |engine|
      #engine.decoration_set.names.clear
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

  shared_context "RDFa rendering" do
    let :graph do
      parse(turtle, :format => :ttl)
    end

    let :serialize_options do
      {:haml_options => {:ugly => false}}
    end

    subject :html do
      @graph = graph
      serialize(serialize_options)
    end
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

      it { should have_xpath("/html/@prefix", %r(dc: http://purl.org/dc/terms/), @debug)}
      it { should have_xpath("/html/@prefix", %r(ex: http://example.com/), @debug)}
      it { should have_xpath("/html/@prefix", %r(ex:), @debug)}
    end

    context "plain literal" do
      subject do
        @graph << [EX.a, EX.b, "foo"]
        serialize(:haml_options => {:ugly => false})
      end

      it { should have_xpath( "/html/body/div/@resource" , "ex:a" ) }
      it { should have_xpath( "//div[@class='property']/span[@property]/@property" , "ex:b" ) }
      it { should have_xpath( "//div[@class='property']/span[@property]/text()" , "foo" ) }
    end

    context "dc:title" do
      subject do
        @graph << [EX.a, RDF::DC.title, "foo"]
        serialize(:prefixes => {:dc => RDF::DC.to_s})
      end

      it { should have_xpath( "/html/head/title/text()" , "foo" ) }
      it { should have_xpath( "/html/body/div/@resource" , "ex:a" ) }
      it { should have_xpath( "/html/body/div/h1/@property" , "dc:title" ) }
      it { should have_xpath( "/html/body/div/h1/text()" , "foo" ) }
    end

    context "typed resources" do
      context "typed resource" do
        subject do
          @graph << [EX.a, RDF.type, EX.Type]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "/html/body/div/@resource" , "ex:a" ) }
        it { should have_xpath( "/html/body/div/@typeof" , "ex:Type" ) }
      end

      context "resource with two types" do
        subject do
          @graph << [EX.a, RDF.type, EX.t1]
          @graph << [EX.a, RDF.type, EX.t2]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "/html/body/div/@resource" , "ex:a" ) }
        it { should have_xpath( "/html/body/div/@typeof" , "ex:t1 ex:t2" ) }
      end
    end

    context "languaged tagged literals" do
      context "literal with language and no default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:prefixes => {:dc => "http://purl.org/dc/terms/"})
        end

        it { should have_xpath( "/html/body/div/h1/@property" , "dc:title" ) }
        it { should have_xpath( "/html/body/div/h1/@lang" , "en" ) }
      end

      context "literal with language and same default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :en)
        end

        it { should have_xpath( "/html/@lang" , "en" ) }
        it { should have_xpath( "/html/body/div/h1/@lang" , false ) }
      end

      context "literal with language and different default language" do
        subject do
          @graph << [EX.a, RDF::DC.title, RDF::Literal("foo", :language => :en)]
          serialize(:lang => :de)
        end

        it { should have_xpath( "/html/@lang" , "de" ) }
        it { should have_xpath( "/html/body/div/h1/@lang" , "en" ) }
      end

      context "property and rel serialize to different elements" do
        subject do
          @graph << [EX.a, RDF.value, "foo"]
          @graph << [EX.a, RDF.value, EX.b]
          serialize
        end

        it { should have_xpath( "/html/body/div/div/ul/li[@property='rdf:value']/text()" , "foo" ) }
        it { should have_xpath( "/html/body/div/div/ul/li/a[@property='rdf:value']/@href" , EX.b.to_s ) }
      end
    end

    context "typed literals" do
      describe "xsd:date" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Date.new("2011-03-18")]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "//span[@property]/@property" , "ex:b" ) }
        it { should have_xpath( "//span[@property]/@datatype" , "xsd:date" ) }
        it { should have_xpath( "//span[@property]/@content" , "2011-03-18" ) }
        it { should have_xpath( "//span[@property]/text()" , "Friday, 18 March 2011") }
      end

      context "xsd:time" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::Time.new("12:34:56")]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "//span[@property]/@property" , "ex:b" ) }
        it { should have_xpath( "//span[@property]/@datatype" , "xsd:time" ) }
        it { should have_xpath( "//span[@property]/@content" , "12:34:56" ) }
        it { should have_xpath( "//span[@property]/text()" , /12:34:56/ ) }
      end

      context "xsd:dateTime" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::DateTime.new("2011-03-18T12:34:56")]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "//span[@property]/@property" , "ex:b" ) }
        it { should have_xpath( "//span[@property]/@datatype" , "xsd:dateTime" ) }
        it { should have_xpath( "//span[@property]/@content" , "2011-03-18T12:34:56" ) }
        it { should have_xpath( "//span[@property]/text()" , /12:34:56 \w+ on Friday, 18 March 2011/) }
      end

      context "rdf:XMLLiteral" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal::XML.new("E = mc<sup>2</sup>: The Most Urgent Problem of Our Time")]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "//span[@property]/@property" , "ex:b" ) }
        it { should have_xpath( "//span[@property]/@datatype" , "rdf:XMLLiteral" ) }
        it { should have_xpath( "//span[@property]", %r(<span [^>]+>E = mc<sup>2</sup>: The Most Urgent Problem of Our Time<\/span>)) }
      end

      context "xsd:string" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => RDF::XSD.string)]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "//span[@property]/@property" , "ex:b" ) }
        it { should have_xpath( "//span[@property]/@datatype" , false ) } # xsd:string implied in RDF 1.1
        it { should have_xpath( "//span[@property]/text()" , "Albert Einstein" ) }
      end

      context "unknown" do
        subject do
          @graph << [EX.a, EX.b, RDF::Literal.new("Albert Einstein", :datatype => EX.unknown)]
          serialize(:haml_options => {:ugly => false})
        end

        it { should have_xpath( "//span[@property]/@property" , "ex:b" ) }
        it { should have_xpath( "//span[@property]/@datatype" , "ex:unknown" ) }
        it { should have_xpath( "//span[@property]/text()" , "Albert Einstein" ) }
      end
    end

    context "multi-valued literals" do
      subject do
        @graph << [EX.a, EX.b, "c"]
        @graph << [EX.a, EX.b, "d"]
        serialize(:haml_options => {:ugly => false})
      end

      it { should have_xpath( "//ul/li[1][@property='ex:b']/text()" , "c" ) }
      it { should have_xpath( "//ul/li[2][@property='ex:b']/text()" , "d" ) }
    end

    context "resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        serialize(:haml_options => {:ugly => false})
      end

      it { should have_xpath( "//div/@resource" , "ex:a" ) }
      it { should have_xpath( "//a/@property" , "ex:b" ) }
      it { should have_xpath( "//a/@href" , EX.c.to_s ) }
    end

    context "multi-valued resource objects" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.a, EX.b, EX.d]
        serialize(:haml_options => {:ugly => false})
      end

      it { should have_xpath( "//div/@resource" , "ex:a" ) }
      it { should have_xpath( "//ul/li[1]/a[@property='ex:b']/@href" , EX.c.to_s ) }
      it { should have_xpath( "//ul/li[2]/a[@property='ex:b']/@href" , EX.d.to_s ) }
    end

    context "booleans" do
      let :turtle do
        %q{
            @prefix lc: <http://lrdesign.com/vocabularies/logical-construct#> .
            <http://localhost:8778/needs/one> <lc:resolved> true .
        }
      end

      include_context "RDFa rendering"

      let :serialize_options do
        { :base_uri => RDF::URI.new("http://localhost:8778/needs/one") }
      end

      it { should have_xpath( "//div/div[@class='property']/span[@datatype='xsd:boolean']/text()", "true") }
    end

    context "lists" do
      context "empty list" do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value () .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div/span[@inlist]/@rel" , 'rdf:value' ) }
        it { should have_xpath( "//div/span[@inlist]/text()" , false ) }
      end


      context "literal" do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value ("Foo") .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div/span[@inlist]/@property" , 'rdf:value' ) }
        it { should have_xpath( "//div/span[@inlist]/text()" , 'Foo' ) }
      end


      context "IRI" do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<foo>) .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div/a[@inlist]/@property" , 'rdf:value' ) }
        it { should have_xpath( "//div/a[@inlist]/@href" , 'foo' ) }
      end

      context "implicit list with hetrogenious membership" do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value ("Foo" <foo>) .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//ul/li[1][@inlist]/@property" , 'rdf:value' ) }
        it { should have_xpath( "//ul/li[1][@inlist]/text()" , 'Foo' ) }
        it { should have_xpath( "//ul/li[2]/a[@inlist]/@property" , 'rdf:value' ) }
        it { should have_xpath( "//ul/li[2]/a[@inlist]/@href" , 'foo' ) }
      end

      context  "property with list and literal" do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value ("Foo" "Bar"), "Baz" .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div[@class='property']/span[@property='rdf:value']/text()" , "Baz" ) }
        it { should have_xpath( "//div[@class='property']/ul/li[1][@inlist][@property='rdf:value']/text()" , 'Foo' ) }
        it { should have_xpath( "//div[@class='property']/ul/li[2][@inlist][@property='rdf:value']/text()" , 'Bar' ) }
      end

      context "multiple rel items" do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<foo> <bar>) .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div[@class='property']/ul/li[1]/a[@inlist][@property='rdf:value']/@href" , 'foo' ) }
        it { should have_xpath( "//div[@class='property']/ul/li[2]/a[@inlist][@property='rdf:value']/@href" , 'bar' ) }
      end

      context "multiple collections", :pending => true do
        let :turtle do
          %q(
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <foo> rdf:value ("Foo"), ("Bar") .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div[@class='property']/ul/li[1][@inlist][@property='rdf:value']/text()" , 'Foo' ) }
        it { should have_xpath( "//div[@class='property']/ul/li[2][@inlist][@property='rdf:value']/text()" , 'Bar' ) }
      end

      context "issue 14" do
        let :turtle do
          %q(
            @base <http://example/> .
            @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
            @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

            <> rdf:value (<needs/one> <needs/two> <needs/three>) .
            <needs/one> rdfs:label "one" .
            <needs/three> rdfs:label "three" .
            <needs/two> rdfs:label "two" .
          )
        end

        include_context "RDFa rendering"

        it { should have_xpath( "//div[@class='property']/ul/li[1][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" , 'one' ) }
        it { should have_xpath( "//div[@class='property']/ul/li[2][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" , 'two' ) }
        it { should have_xpath( "//div[@class='property']/ul/li[3][@inlist][@rel='rdf:value']/h1[@property='rdfs:label']/text()" , 'three' ) }
      end
    end

    context "included resource definitions" do
      subject do
        @graph << [EX.a, EX.b, EX.c]
        @graph << [EX.c, EX.d, EX.e]
        serialize(:haml_options => {:ugly => false})
      end

      it { should have_xpath( "/html/body/div/@resource" , "ex:a" ) }
      it { should have_xpath( "//div[@resource='ex:a']/div[@class='property']/div[@rel]/@rel" , "ex:b" ) }
      it { should have_xpath( "//div[@rel]/@resource" , "ex:c" ) }
      it { should have_xpath( "//div[@rel]/div[@class='property']/a/@href" , EX.e.to_s ) }
      it { should have_xpath( "//div[@rel]/div[@class='property']/a/@property" , "ex:d" ) }
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
