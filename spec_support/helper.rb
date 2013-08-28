require 'cadre/rspec'
require 'roadforest/test-support/matchers'

RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [
    %r{gems/rspec-core},
    %r{gems/rspec-expectations}
  ]
  config.run_all_when_everything_filtered = true
  config.add_formatter(Cadre::RSpec::NotifyOnCompleteFormatter)
  config.add_formatter(Cadre::RSpec::QuickfixFormatter)
end
