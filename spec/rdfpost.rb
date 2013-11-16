require 'rdf/turtle'
require 'roadforest/content-handling/type-handlers/rdfpost'

describe RoadForest::MediaType::Handlers::RDFPost do
  let :handler do
    RoadForest::MediaType::Handlers::RDFPost.new
  end

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

  let :target_graph do
    graph = ::RDF::Graph.new
    ::RDF::Turtle::Reader.new(turtle_source).each_statement do |stmt|
      graph.insert(stmt)
    end
    graph
  end


  let :source_string do
    <<-EOS
rdf=
&v=http://xmlns.com/foaf/0.1/
&n=rdf &v=http://www.w3.org/1999/02/22-rdf-syntax-ns%23
&n=dc &v=http://purl.org/dc/elements/1.1/
&sb=o
 &pv=givenname
  &ol=Ora
 &pv=surname
  &ol=Lasilla
 &pn=dc &pv=creator
  &ob=b
&sb=b
 &pn=rdf &pv=type
  &ov=Document
 &pn=dc &pv=title
  &ol=Moby+Dick
    EOS
  end

  let :source_list do
    URI::decode_www_form(source_string)
  end

  it "should parse the source to target" do
    handler.network_to_local("http://example.com",source_list).should == target_graph
  end
end
