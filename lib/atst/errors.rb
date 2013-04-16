module ATST
  class Error < ::StandardError; end
  class NoSolutions < Error; end
  class AmbiguousSolutions < Error; end
end
