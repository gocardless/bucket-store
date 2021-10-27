# frozen_string_literal: true

require File.expand_path("lib/bucket_store/version", __dir__)

Gem::Specification.new do |s|
  s.name        = "bucket_store"
  s.version     = BucketStore::VERSION.dup
  s.authors     = ["GoCardless Engineering"]
  s.email       = ["engineering@gocardless.com"]
  s.summary     = "A helper library to access cloud storage services"
  s.description = <<-DESCRIPTION
    A helper library to access cloud storage services such as Google Cloud Storage.
  DESCRIPTION
  s.homepage      = "https://github.com/gocardless/bucket-store"
  s.license       = "MIT"

  s.files = Dir["lib/**/*", "README.md"]

  s.required_ruby_version = ">= 2.6"

  s.add_dependency "aws-sdk-s3", "~> 1"
  s.add_dependency "google-cloud-storage", "~> 1.31"

  s.add_development_dependency "gc_ruboconfig", "~> 2.29"
  s.add_development_dependency "pry-byebug", "~> 3.9"
  s.add_development_dependency "rspec", "~> 3.10"
  s.add_development_dependency "rspec_junit_formatter", "~> 0.4.1"
  s.add_development_dependency "rubocop", "~> 1.22"
  s.add_development_dependency "rubocop-performance", "~> 1.11"
  s.add_development_dependency "rubocop-rspec", "~> 2.5"
end
