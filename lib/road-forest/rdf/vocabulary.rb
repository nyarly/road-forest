require 'road-forest/rdf'

module RoadForest::RDF
  module Vocabulary
    class RF < ::RDF::Vocabulary("http://lrdesign.com/rdf/road-forest#")
      property :Impulse
      property :impulse
      property :begunAt
    end
  end
end
