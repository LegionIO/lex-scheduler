# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'legion/logging'
require 'legion/settings'
require 'legion/cache/helper'
require 'legion/crypt/helper'
require 'legion/data/helper'
require 'legion/json/helper'
require 'legion/transport'

module Legion
  module Extensions
    module Helpers
      module Lex
        include Legion::Logging::Helper if defined?(Legion::Logging::Helper)
        include Legion::Settings::Helper if defined?(Legion::Settings::Helper)
        include Legion::Cache::Helper if defined?(Legion::Cache::Helper)
        include Legion::Crypt::Helper if defined?(Legion::Crypt::Helper)
        include Legion::Data::Helper if defined?(Legion::Data::Helper)
        include Legion::JSON::Helper if defined?(Legion::JSON::Helper)
        include Legion::Transport::Helper if defined?(Legion::Transport::Helper)
      end
    end

    module Actors
      class Every
        include Helpers::Lex
      end

      class Once
        include Helpers::Lex
      end
    end
  end
end

require 'legion/extensions/scheduler'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
