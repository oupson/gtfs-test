# frozen_string_literal: true

require_relative "lib/gtfs/version"

Gem::Specification.new do |spec|
  spec.name = "gtfs"
  spec.version = GtfsData::VERSION
  spec.authors = ["oupson"]
  spec.email = ["oupson1er@gmail.com"]

  spec.summary = "Play with gtfs files"
  spec.homepage = "https://github.com/oupson/gtfs-test"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/oupson/gtfs-test"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency 'rubyzip', '~> 1.2'
  spec.add_dependency 'sqlite3', '~> 1.6'
  spec.add_dependency 'ruby-progressbar', '~> 1.11'
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'terminal-table', '~> 3.0'

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
