# frozen_string_literal: true

require_relative "lib/dial/version"

Gem::Specification.new do |spec|
  spec.name = "dial"
  spec.version = Dial::VERSION
  spec.authors = ["Joshua Young"]
  spec.email = ["djry1999@gmail.com"]

  spec.summary = "A modern Rails profiler"
  spec.homepage = "https://github.com/joshuay03/dial"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.1"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["{lib}/**/*", "**/*.{gemspec,md,txt}"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7", "< 8.2"
  spec.add_dependency "activerecord", ">= 7", "< 8.2"
  spec.add_dependency "actionpack", ">= 7", "< 8.2"
  spec.add_dependency "vernier", "~> 1.3"
  spec.add_dependency "prosopite", "~> 1.4"
  spec.add_dependency "pg_query", "~> 5.1"
end
