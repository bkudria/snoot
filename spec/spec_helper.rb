require "simplecov"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "snoot"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Snoot::Spec::Factories

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
