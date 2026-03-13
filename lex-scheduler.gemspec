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

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'fugit', '>= 1.9'

  spec.add_development_dependency 'bundler', '>= 2'
  spec.add_development_dependency 'legionio'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
end
