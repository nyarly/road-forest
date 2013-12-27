module RoadForest
  class << self
    attr_accessor :debug_io

    def debug(message)
      return if @debug_io.nil?
      @debug_io.puts(message)
    end
  end
end
