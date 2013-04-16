module RoadForest
  #XXX Worth doing some meta to get sanity checking of configs here? Better
  #fail early if there's no DB configured, right?
  class ServicesHost
    def initialize
    end

    attr_accessor :router
  end
end
