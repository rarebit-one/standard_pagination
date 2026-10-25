require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  skip "/spec/"
end

ENV["RAILS_ENV"] = "test"

require_relative "support/test_app"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |m|
    m.verify_partial_doubles = true
  end

  config.order = :random
  Kernel.srand config.seed

  config.before do
    StandardPagination.reset_config!
    Widget.delete_all
  end
end
