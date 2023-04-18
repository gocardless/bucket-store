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
      # Ruby's GCS library does not natively support setting up a simulator, but it allows
      # for a specific endpoint to be passed down which has the same effect. The simulator
      # needs to be special cased as in that case we want to bypass authentication,
      # which we can only do by accessing the `.anonymous` version of the Storage class.
      simulator_endpoint = ENV["STORAGE_EMULATOR_HOST"]
      is_simulator = !simulator_endpoint.nil?

      args = {
        endpoint: simulator_endpoint,
        timeout: timeout_seconds,
      }.compact

      @storage = if is_simulator
                   Google::Cloud::Storage.anonymous(**args)
                 else
                   Google::Cloud::Storage.new(**args)
                 end
    end

    def upload!(bucket:, key:, file:)
      get_bucket(bucket).create_file(file, key)

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
