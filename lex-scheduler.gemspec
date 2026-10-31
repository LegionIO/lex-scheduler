# frozen_string_literal: true

require_relative 'lib/legion/extensions/scheduler/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-scheduler'
  spec.version       = Legion::Extensions::Scheduler::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX::Scheduler'
  spec.description   = 'Schedules and manages delayed, async and cron style tasks'
  spec.homepage      = 'https://github.com/LegionIO/lex-scheduler'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-scheduler'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-scheduler'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-scheduler'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-scheduler/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |file| file.match(%r{^(test|spec|features|\.ci-dependencies)/}) || file.end_with?('.gem', 'Gemfile.lock') }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'fugit', '>= 1.9'
  spec.add_dependency 'legion-cache', '>= 1.3.11'
  spec.add_dependency 'legion-data', '>= 1.11.0'
  spec.add_dependency 'legion-json', '>= 1.2.1'
  spec.add_dependency 'legion-logging', '>= 1.3.2'
  spec.add_dependency 'legion-settings', '>= 1.5.0'
  spec.add_dependency 'lex-tasker', '>= 0.4.0'
end
