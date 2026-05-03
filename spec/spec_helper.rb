require "simplecov"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Once lib/snoot.rb exists, uncomment to wire the implementation in:
# require "snoot"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
