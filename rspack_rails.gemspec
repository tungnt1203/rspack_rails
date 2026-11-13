# frozen_string_literal: true

require_relative "lib/rspack_rails/version"

Gem::Specification.new do |spec|
  spec.name = "rspack_rails"
  spec.version = RspackRails::VERSION
  spec.authors = ["tungnt"]
  spec.email = ["tungnguyen120301@gmail.com"]

  spec.summary = "Rspack integration for Ruby on Rails"
  spec.description = "Bundle Rails JavaScript with Rspack: one-command installer, dev server with " \
                     "hot module replacement, Stimulus controller autoloading and a setup doctor. " \
                     "Works with Propshaft and Sprockets."
  spec.license = "MIT"
  spec.homepage = "https://github.com/tungnt1203/rspack_rails"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/tungnt1203/rspack_rails/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "sig/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.0", "< 9"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
