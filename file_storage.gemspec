# frozen_string_literal: true

require File.expand_path("lib/file_storage/version", __dir__)

Gem::Specification.new do |s|
  s.name        = "file_storage"
  s.version     = FileStorage::VERSION.dup
  s.authors     = ["GoCardless Engineering"]
  s.email       = ["developers@gocardless.com"]
  s.summary     = "A helper library to access cloud storage services"
  s.description = <<-DESCRIPTION
    A helper library to access cloud storage services such as Google Cloud Storage.
  DESCRIPTION

  s.files = Dir["lib/**/*", "README.md"]

  s.add_dependency "activesupport", "~> 6.0.3.3"
  s.add_dependency "google-cloud-storage", "~> 1.28"
  s.add_dependency "values", "~> 1.8"

  s.add_development_dependency "gc_ruboconfig", "~> 2.19"
  s.add_development_dependency "pry-byebug", "~> 3.9"
  s.add_development_dependency "rspec", "~> 3.9"
  s.add_development_dependency "rspec_junit_formatter", "~> 0.2"
  s.add_development_dependency "rubocop", "~> 0.91"
  s.add_development_dependency "rubocop-performance", "~> 1.8"
  s.add_development_dependency "rubocop-rspec", "~> 1.43.2"
end
