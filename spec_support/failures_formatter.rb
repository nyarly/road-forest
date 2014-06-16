require 'rspec/core/formatters/base_formatter'

module RSpec::Core::Formatters
  class Failures < BaseFormatter
    def dump_failures
      failed_examples.each do |example|
        output.puts RSpec::Core::Metadata::relative_path(example.location)
      end
    end
  end
end
