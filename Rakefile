# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "github-xcode-bot-builder"
  gem.homepage = "http://github.com/ModCloth/github-xcode-bot-builder"
  gem.license = "MIT"
  gem.summary = %Q{Create Xcode bots to run when github pull requests are created or updated}
  gem.description = %Q{A command line tool that can be run via cron that configures and manages Xcode server bots for each pull request}
  gem.email = ""
  gem.authors = ["ModCloth", "Two Bit Labs", "Geoffery Nix", "Todd Huss", "Banno"]
  gem.executables = ['bot-sync-github', 'bot-devices', 'bot-status', 'bot-delete']
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "github-xcode-bot-builder #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
