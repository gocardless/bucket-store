# frozen_string_literal: true

require "stringio"
require "uri"

require "google/cloud/storage"

module BucketStore
  class Gcs
    DEFAULT_TIMEOUT_SECONDS = 30

    def self.build(timeout_seconds = DEFAULT_TIMEOUT_SECONDS)
      Gcs.new(timeout_seconds)
    end

    def initialize(timeout_seconds)
      @storage = Google::Cloud::Storage.new(
        timeout: timeout_seconds,
      )
    end

    def upload!(bucket:, key:, content:)
      buffer = StringIO.new(content)
      get_bucket(bucket).create_file(buffer, key)

      {
        bucket: bucket,
        key: key,
      }
    end

    def download(bucket:, key:)
      file = get_bucket(bucket).file(key)

      buffer = StringIO.new
      file.download(buffer)

      {
        bucket: bucket,
        key: key,
        content: buffer.string,
      }
    end

    def list(bucket:, key:, page_size:)
      Enumerator.new do |yielder|
        token = nil

        loop do
          page = get_bucket(bucket).files(prefix: key, max: page_size, token: token)
          yielder.yield({
            bucket: bucket,
            keys: page.map(&:name),
          })

          break if page.token.nil?

          token = page.token
        end
      end
    end

    def delete!(bucket:, key:)
      get_bucket(bucket).file(key).delete

      true
    end

    def presigned_url(bucket:, key:, expiry:)
      get_bucket(bucket).file(key).signed_url(expires: expiry)
    end

    private

    attr_reader :storage

    def get_bucket(name)
      # Lookup only checks that the bucket actually exist before doing any work on it.
      # Unfortunately it also requires a set of extra permissions that are not necessarily
      # going to be granted for service accounts. Given that if the bucket doesn't exist
      # we'll get errors down the line anyway, we can safely skip the lookup without loss
      # of generality.
      storage.bucket(name, skip_lookup: true)
    end
  end
end
