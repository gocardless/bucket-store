# frozen_string_literal: true

require "logger"
require "bucket_store"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  if config.filter_manager.exclusions.rules.empty?
    # Do not run integration tests unless an explicit `--tag` is set. This means
    # that running `bundle exec rspec` will only run the unit tests, which is the
    # generally preferred behaviour since integration tests require additional
    # setup to run.
    config.filter_run_excluding :integration
  end

  # Silence log output when running tests
  BucketStore.configuration.logger = Logger.new(nil)

  config.before do
    BucketStore::InMemory.reset!
  end
end
