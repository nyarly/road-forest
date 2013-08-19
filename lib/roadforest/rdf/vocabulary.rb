require 'roadforest/rdf'

module RoadForest::RDF
  module Vocabulary
    class RF < ::RDF::Vocabulary("http://lrdesign.com/rdf/roadforest#")
      property :Impulse
      property :impulse
      property :begunAt
    end
  end
end
