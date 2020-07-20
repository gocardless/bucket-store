# frozen_string_literal: true

require "stringio"
require "uri"

require "google/cloud/storage"

module FileStorage
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

    def list(bucket:, key:)
      matching_keys = get_bucket(bucket).files(prefix: key).map(&:name)
      {
        bucket: bucket,
        keys: matching_keys,
      }
    end

    private

    attr_reader :storage

    def get_bucket(name)
      # Lookup only checks that the bucket actually exist before doing any work on it.
      # Unfortunately it also requires a set of permissions that are not currently
      # granted for our service account.
      storage.bucket(name, skip_lookup: true)
    end
  end
end