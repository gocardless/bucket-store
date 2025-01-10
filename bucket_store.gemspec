# frozen_string_literal: true

require File.expand_path("lib/bucket_store/version", __dir__)

Gem::Specification.new do |s|
  s.name        = "bucket_store"
  s.version     = BucketStore::VERSION.dup
  s.authors     = ["GoCardless Engineering"]
  s.email       = ["engineering@gocardless.com"]
  s.summary     = "A helper library to access cloud storage services"
  s.description = <<-DESCRIPTION
    A helper library to access cloud storage services such as Google Cloud Storage or S3.
  DESCRIPTION
  s.homepage      = "https://github.com/gocardless/bucket-store"
  s.license       = "MIT"

  s.files = Dir["lib/**/*", "README.md"]

  s.required_ruby_version = ">= 3.0"

  s.add_dependency "aws-sdk-s3", ">= 1.177"
  s.add_dependency "google-cloud-storage", ">= 1.54"

  s.metadata["rubygems_mfa_required"] = "true"
end
