# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

ci_root = File.expand_path('.ci-dependencies', __dir__)
companion_root = Dir.exist?(ci_root) ? ci_root : File.expand_path('../..', __dir__)
%w[legion-settings legion-data legion-transport].each do |name|
  path = File.join(companion_root, name)
  gem name, path: path if File.file?(File.join(path, "#{name}.gemspec"))
end

group :test do
  gem 'rake'
  gem 'rspec', '~> 3.13'
  gem 'rubocop', '~> 1.75'
  gem 'rubocop-legion', '~> 0.1', require: false
  gem 'simplecov'
  gem 'sqlite3'
end
