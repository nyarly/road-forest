require 'rdf/turtle'
require 'roadforest/type-handlers/rdfpost'

describe RoadForest::TypeHandlers::RDFPost do
  let :handler do
    RoadForest::TypeHandlers::RDFPost.new
  end

  shared_examples "a parsed form submission" do
    let :target_graph do
      graph = ::RDF::Graph.new
      ::RDF::Turtle::Reader.new(turtle_source).each_statement do |stmt|
        graph.insert(stmt)
      end
      graph
    end

    #Allows for tests to break and indent form encoded strings for clarity
    #Does mean that embedded spaces will need to be "+"'d first and %-encoded
    let :clean_string do
      source_string.gsub(/\s*/,"")
    end

    let :source_list do
      URI::decode_www_form(clean_string)
    end

    let :result_graph do
      handler.network_to_local("http://example.com",source_list)
    end

    it "should parse the source to target" do
      result_graph.should be_equivalent_to target_graph
    end
  end

  #XXX Need tests for malformed graphs

  describe "Without any object fields" do
    let :source_string do
      <<-EOS
      rdf=
        &n=ex&v=http%3A%2F%2Fexample.com%2F
        &n=rdf&v=http%3A%2F%2Fwww.w3.org%2F1999%2F02%2F22-rdf-syntax-ns%23
          &sn=ex&sv=a
          &pn=ex&pv=b"
      EOS
    end

    let :turtle_source do
      ""
    end

    it_behaves_like "a parsed form submission"
  end

  describe "The documentation example" do
    let :turtle_source do
      <<-EOT
        @prefix : <http://xmlns.com/foaf/0.1/> .
        @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
        @prefix dc: <http://purl.org/dc/elements/1.1/> .
        _:o
         :givenname
          "Ora" ;
         :surname
          "Lasilla" ;
         dc:creator
          _:b .
        _:b
         rdf:type
          :Document ;
         dc:title
          "Moby Dick" .
      EOT
    end

    let :source_string do
      <<-EOS
        rdf=
        &v=http://xmlns.com/foaf/0.1/
        &n=rdf &v=http://www.w3.org/1999/02/22-rdf-syntax-ns%23
        &n=dc &v=http://purl.org/dc/elements/1.1/

        &sb=o &pv=givenname &ol=Ora
              &pv=surname &ol=Lasilla
              &pn=dc &pv=creator &ob=b
        &sb=b &pn=rdf &pv=type &ov=Document
              &pn=dc &pv=title &ol=Moby+Dick
      EOS
    end

    it_behaves_like "a parsed form submission"
  end

end
