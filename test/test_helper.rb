ENV["RAILS_ENV"] ||= "test"

# Cobertura de código: COVERAGE=1 bin/rails test → relatório em coverage/index.html
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
  end
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    if ENV["COVERAGE"]
      # Cada processo paralelo grava seu próprio resultado; o SimpleCov junta tudo no fim.
      parallelize_setup { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
      parallelize_teardown { |_worker| SimpleCov.result }
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
