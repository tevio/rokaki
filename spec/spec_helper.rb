# frozen_string_literal: true

require 'bundler/setup'
require 'rokaki'
require 'pry'
require 'factory_bot'

FactoryBot.definition_file_paths = %w[./spec/factories]
# FactoryBot.find_definitions

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  # focus tests
  config.run_all_when_everything_filtered = true
  config.filter_run_including :focus => true
end
