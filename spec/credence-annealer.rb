require 'roadforest/source-rigor/credence-annealer'
require 'roadforest/graph/graph-store'
require 'timeout'

describe RoadForest::SourceRigor::CredenceAnnealer do
  let :graph do
    RoadForest::Graph::GraphStore.new
  end

  subject :annealer do
    RoadForest::SourceRigor::CredenceAnnealer.new(graph)
  end

  it "should run it's block at least once" do
    tested = false
    annealer.resolve do
      tested = true
    end
    tested.should be_true
  end

  it "should re-run it's block until the GraphStore settles" do
    graph.stub(:quiet_impulse?).and_return(false, false, false, false, true) #called twice per resolution loop

    times_run = 0
    annealer.resolve do
      times_run += 1
    end

    times_run.should == 3
  end

  it "should produce an error in some infinite-loop style situation" do
    graph.stub(:quiet_impulse?).and_return(false)

    expect do
      Timeout::timeout(1) do
        annealer.resolve do
        end
      end
    end.to raise_error(/Annealing failed/)
  end

end
