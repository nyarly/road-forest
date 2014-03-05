require 'roadforest/source-rigor'
require 'roadforest/graph/graph-store'

describe RoadForest::SourceRigor do
  describe "credence policy" do
    describe ":gossip" do
      let :graph_store do
        RoadForest::Graph::GraphStore.new
      end

      let :source_rigor do
        RoadForest::SourceRigor::Engine.new.tap do |source_rigor|
          source_rigor.investigator_list(:null)
          source_rigor.policy_list(:may_subject, :any)
        end
      end

      let :subject do
        RDF::URI.new("urn://subject")
      end

      let :not_subject do
        RDF::URI.new("urn://not_subject")
      end

      let :property do
        RDF::URI.new("urn://property")
      end

      let :query do
        RoadForest::SourceRigor::ResourceQuery.new([], {}) do |query|
          query.subject_context = subject
          query.source_rigor = source_rigor
          query.pattern( [subject, property, :value])
        end
      end

      let :results do
        query.execute(graph_store)
      end


      it "should return results about a subject when that context is not available" do
        graph_store.add_statement(subject, property, 7, not_subject)
        results.length.should == 1
      end

      it "should return the results from the subject's context when it is available" do
        graph_store.add_statement(subject, property, 7, not_subject)
        graph_store.add_statement(subject, property, 11, subject)

        results.length.should == 1
        results.first.value.object.should == 11
      end
    end
  end
end
