require 'roadforest/graph'

module RoadForest::Graph
  module Etagging
    def etag_from(graph)
      require 'openssl'
      quads = sorted_quads(graph)
      mapped = blank_mapped(quads)
      strings = mapped.map(&:inspect)

      ripe = OpenSSL::Digest::RIPEMD160.new
      mapped.each do |quad|
        ripe << quad.inspect
      end
      "W/\"#{ripe.base64digest}\""
    end

    def blank_mapped(quads)
      sequence = 0
      mapping = Hash.new do |h,k|
        h[k] = RDF::Node.new(sequence+=1)
      end

      quads.map do |quad|
        quad.map do |term|
          case term
          when RDF::Node
            mapping[term].to_s
          when nil
            nil
          else
            term.to_s
          end
        end
      end
    end

    def sorted_quads(graph)
      graph.statements.map do |statement|
        [statement.subject, statement.predicate, statement.object, statement.context]
      end.sort_by do |quad|
        quad.map do |term|
          case term
          when RDF::Node
            nil
          else
            term
          end
        end.join("/")
      end
    end
  end
end
