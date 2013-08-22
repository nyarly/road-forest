require 'cadre/rspec'
RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [
    %r{gems/rspec-core}
  ]
  config.run_all_when_everything_filtered = true
  config.add_formatter(Cadre::RSpec::NotifyOnCompleteFormatter)
  config.add_formatter(Cadre::RSpec::QuickfixFormatter)
end
