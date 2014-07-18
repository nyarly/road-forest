require 'cgi'
require 'mechanize'

require 'rdf'
require 'rdf/xsd'
require 'rdf/turtle'

require 'roadforest/interfaces'
require 'roadforest/application'
require 'roadforest/graph/vocabulary'
require 'roadforest/augmentations'
require 'roadforest/content-handling/common-engines'
require 'roadforest/type-handlers/rdfpost'
require 'roadforest/type-handlers/rdfa'

class EX < RDF::Vocabulary("http://example.com/"); end

describe "The full affordances flow" do
  Aff = RoadForest::Graph::Af

  let :service_host do
    RoadForest::Application::ServicesHost.new.tap do |services|
      services.root_url = "http://example.com/a"
      services.authz.cleartext_grants!
    end
  end

  let :content_engine do
    RoadForest::ContentHandling.rdf_engine
  end

  let :application do
    double("RoadForest::Application").tap do |app|
      app.stub(:services).and_return(service_host)
      app.stub(:default_content_engine).and_return(content_engine)
    end
  end

  let :debug do
    []
  end

  let :augmenter do
    RoadForest::Augment::Augmenter.new(service_host)
  end

  let :rdfa do
    serialize(complete_graph, :haml_options => {:ugly => false})
  end

  before(:all) do
    @valise = Valise.define do
      ro up_to("spec") + "../lib/roadforest"
    end

    @tilt_cache = ::Tilt::Cache.new
  end

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

  # Serialize  @graph to a string and compare against regexps
  def serialize(graph, options = {})

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

    engine = RoadForest::TypeHandlers::RDFaWriter::RenderEngine.new(graph, options[:debug]) do |engine|
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

  let :complete_graph do
    RDF::Repository.new.tap do |graph|
      base_graph.each_statement do |stmt|
        graph << stmt
      end

      affordance_graph.each_statement do |stmt|
        graph << stmt
      end
    end
  end

  shared_context "written to RDFa" do
    subject do
      rdfa
    end

    let :put_uri do
      EX.a.join("put").to_s
    end

    it "should parse RDFa back to base_graph" do
      #XXX subject isn't right here...
      parse(subject, :format => :rdfa).should be_equivalent_graph(base_graph, :trace => debug)
    end
  end

  shared_context "affordance augmentation" do
    subject :augmented_graph do
      augmenter.augment(base_graph)
    end

    it{ should be_equivalent_graph(complete_graph) }
  end

  shared_context "resubmitted RDFPOST" do
    let :mechanize do
      Mechanize.new
    end

    let :base_url do
      EX.a
    end

    let :form do
      Mechanize::Page.new(base_url, nil, rdfa, nil, mechanize).forms.first
    end

    let :post_data do
      form.request_data
    end

    subject :received_graph do
      RDF::Repository.new.tap do |graph|
        list = URI::decode_www_form(post_data)
        RoadForest::TypeHandlers::RDFPost::Reader.new(list).each_statement do |stmt|
          graph.insert(stmt)
        end
      end
    end

    it{ should be_equivalent_graph(base_graph) }
  end

  #Needed tests
  #  3 levels nesting of subject pred subject pred subject (tricky in terms
  #  of RDFPOST repetition) Each subject needs literal terms
  #
  #Non-afforded subject, property with afforded subject
  #  (Currently, forms are only produced by document)

  #Proper affordances on parents and children
  #
  #Affordance payloads
  #
  #Parameterized navigations
  #
  #Embed affordances
  #
  #Re-routing + method support resources (i.e.
  #  POST other/route/put -> PUT other/route )

  describe "a resource that refers to another resource" do
    class TestInterface < RoadForest::Interface::RDF
    end

    before :each do
      service_host.router.add :test, ["a"], :parent, TestInterface
      service_host.router.add :target, ["z"], :parent, TestInterface
    end

    let :base_graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, EX.z]
      end
    end

    let :affordance_graph do
      caff = ::RDF::Node.new(:caff)
      uaff = ::RDF::Node.new(:uaff)
      naff = ::RDF::Node.new(:naff)
      onaff = ::RDF::Node.new(:onaff)
      daff = ::RDF::Node.new(:daff)

      RDF::Repository.new.tap do |graph|
        graph << [caff, ::RDF.type, Aff.Update]
        graph << [caff, Aff.target, EX.a]
        graph << [uaff, ::RDF.type, Aff.Create]
        graph << [uaff, Aff.target, EX.a]
        graph << [daff, ::RDF.type, Aff.Remove]
        graph << [daff, Aff.target, EX.a]
        graph << [naff, ::RDF.type, Aff.Navigate]
        graph << [naff, Aff.target, EX.a]
        graph << [onaff, ::RDF.type, Aff.Navigate]
        graph << [onaff, Aff.target, EX.z]
      end
    end

    it_behaves_like "written to RDFa"
    it_behaves_like "affordance augmentation"
    it_behaves_like "resubmitted RDFPOST"
  end

  describe "a resource that refers to a foreign IRI" do
    class TestInterface < RoadForest::Interface::RDF
    end

    before :each do
      service_host.router.add :test, ["a"], :parent, TestInterface
    end

    let :base_graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, RDF::Resource.new("http://google.com/help")]
      end
    end

    let :affordance_graph do
      caff = ::RDF::Node.new(:caff)
      uaff = ::RDF::Node.new(:uaff)
      naff = ::RDF::Node.new(:naff)
      daff = ::RDF::Node.new(:daff)

      RDF::Repository.new.tap do |graph|
        graph << [caff, ::RDF.type, Aff.Update]
        graph << [caff, Aff.target, EX.a]
        graph << [uaff, ::RDF.type, Aff.Create]
        graph << [uaff, Aff.target, EX.a]
        graph << [daff, ::RDF.type, Aff.Remove]
        graph << [daff, Aff.target, EX.a]
        graph << [naff, ::RDF.type, Aff.Navigate]
        graph << [naff, Aff.target, EX.a]
      end
    end

    it_behaves_like "written to RDFa"
    it_behaves_like "affordance augmentation"
    it_behaves_like "resubmitted RDFPOST"
  end

  describe "a resource that refers to a unserved IRI" do
    class TestInterface < RoadForest::Interface::RDF
    end

    before :each do
      service_host.router.add :test, ["a"], :parent, TestInterface
    end

    let :base_graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, EX.z]
      end
    end

    let :affordance_graph do
      caff = ::RDF::Node.new(:caff)
      uaff = ::RDF::Node.new(:uaff)
      naff = ::RDF::Node.new(:naff)
      daff = ::RDF::Node.new(:daff)
      zaff = ::RDF::Node.new(:zaff)

      RDF::Repository.new.tap do |graph|
        graph << [caff, ::RDF.type, Aff.Update]
        graph << [caff, Aff.target, EX.a]
        graph << [uaff, ::RDF.type, Aff.Create]
        graph << [uaff, Aff.target, EX.a]
        graph << [daff, ::RDF.type, Aff.Remove]
        graph << [daff, Aff.target, EX.a]
        graph << [naff, ::RDF.type, Aff.Navigate]
        graph << [naff, Aff.target, EX.a]
        graph << [zaff, ::RDF.type, Aff.Null]
        graph << [zaff, Aff.target, EX.z]
      end
    end

    it_behaves_like "written to RDFa"
    it_behaves_like "affordance augmentation"
    it_behaves_like "resubmitted RDFPOST"
  end

  describe "a resource that refers to a blob" do
    class TestInterface < RoadForest::Interface::RDF
    end

    class Blobby < RoadForest::Interface::Blob
    end

    before :each do
      service_host.router.add :test, ["a"], :parent, TestInterface
      service_host.router.add :blob, ["z"], :leaf, RoadForest::Interface::Blob do |route|
        route.content_engine = RoadForest::ContentHandling.images_engine
      end
    end

    let :base_graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, EX.z]
      end
    end

    let :affordance_graph do
      caff = ::RDF::Node.new(:caff)
      uaff = ::RDF::Node.new(:uaff)
      naff = ::RDF::Node.new(:naff)
      daff = ::RDF::Node.new(:daff)
      eaff = ::RDF::Node.new(:eaff)

      RDF::Repository.new.tap do |graph|
        graph << [caff, ::RDF.type, Aff.Update]
        graph << [caff, Aff.target, EX.a]
        graph << [uaff, ::RDF.type, Aff.Create]
        graph << [uaff, Aff.target, EX.a]
        graph << [daff, ::RDF.type, Aff.Remove]
        graph << [daff, Aff.target, EX.a]
        graph << [naff, ::RDF.type, Aff.Navigate]
        graph << [naff, Aff.target, EX.a]
        graph << [eaff, ::RDF.type, Aff.Embed]
        graph << [eaff, Aff.target, EX.z]
      end
    end

    it_behaves_like "written to RDFa"
    it_behaves_like "affordance augmentation"
    it_behaves_like "resubmitted RDFPOST"
  end

  describe "simple updateable resource" do
    class TestInterface < RoadForest::Interface::RDF
    end

    before :each do
      service_host.router.add :test, ["a"], :parent, TestInterface
    end

    let :base_graph do
      RDF::Repository.new.tap do |graph|
        graph << [EX.a, EX.b, 17]
      end
    end

    let :affordance_graph do
      caff = ::RDF::Node.new(:caff)
      uaff = ::RDF::Node.new(:uaff)
      naff = ::RDF::Node.new(:naff)
      daff = ::RDF::Node.new(:daff)

      RDF::Repository.new.tap do |graph|
        graph << [caff, ::RDF.type, Aff.Update]
        graph << [caff, Aff.target, EX.a]
        graph << [uaff, ::RDF.type, Aff.Create]
        graph << [uaff, Aff.target, EX.a]
        graph << [daff, ::RDF.type, Aff.Remove]
        graph << [daff, Aff.target, EX.a]
        graph << [naff, ::RDF.type, Aff.Navigate]
        graph << [naff, Aff.target, EX.a]
      end
    end

    it_behaves_like "written to RDFa" do
      it { should have_xpath('//form/@action', put_uri) }
      it { should have_xpath("//form[@action='#{put_uri}']/@method", "POST") }
      it { should have_xpath("//form[@action='#{put_uri}']/input[@type='hidden']/@name", "rdf") }
    end

    it_behaves_like "affordance augmentation" do
      it "should add Update affordance" do
        subject.should match_query {
          pattern [:node, RDF.type, Aff.Update]
          pattern [:node, Aff.target, EX.a]
        }
      end

      it "should add Create affordance" do
        subject.should match_query {
          pattern [:node, RDF.type, Aff.Create]
          pattern [:node, Aff.target, EX.a]
        }
      end
      #it "should add Delete affordance"
      #it "should add Navigable affordance to child"
    end

    it_behaves_like "resubmitted RDFPOST"
  end
end
