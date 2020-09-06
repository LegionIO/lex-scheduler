require_relative 'lib/legion/extensions/scheduler/version'

Gem::Specification.new do |spec|
  spec.name          = "legion-extensions-scheduler"
  spec.version       = Legion::Extensions::Scheduler::VERSION
  spec.authors       = ["Esity"]
  spec.email         = ["matthewdiverson@gmail.com"]

  spec.summary       = %q{LEX::Scheduler}
  spec.description   = %q{Schedules and manages delayed, async and cron style tasks}
  spec.homepage      = "https://bitbucket.org/legion-io/lex-scheduler"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")


  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://bitbucket.org/legion-io/lex-scheduler"
  spec.metadata["changelog_uri"] = "https://bitbucket.org/legion-io/lex-scheduler/src/master/CHANGELOG.md"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'legionio'
end
