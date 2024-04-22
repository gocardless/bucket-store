# frozen_string_literal: true

require "uri"

module BucketStore
  class S3
    DEFAULT_TIMEOUT_SECONDS = 30

    def self.load_client_library
      @load_client_library ||= require "aws-sdk-s3"
    end

    def self.build(open_timeout_seconds = DEFAULT_TIMEOUT_SECONDS,
                   read_timeout_seconds = DEFAULT_TIMEOUT_SECONDS)
      new(open_timeout_seconds, read_timeout_seconds)
    end

    def initialize(open_timeout_seconds, read_timeout_seconds)
      self.class.load_client_library

      @storage = Aws::S3::Client.new(
        http_open_timeout: open_timeout_seconds,
        http_read_timeout: read_timeout_seconds,
      )
    end

    def upload!(bucket:, key:, file:)
      storage.put_object(
        bucket: bucket,
        key: key,
        body: file,
      )

      {
        bucket: bucket,
        key: key,
      }
    end

    def download(bucket:, key:, file:)
      storage.get_object(
        response_target: file,
        bucket: bucket,
        key: key,
      )
    end

    def list(bucket:, key:, page_size:)
      Enumerator.new do |yielder|
        page = storage.list_objects_v2(bucket: bucket, prefix: key, max_keys: page_size)

        loop do
          yielder.yield({
            bucket: bucket,
            keys: page.contents.map(&:key),
          })

          break unless page.next_page?

          page = page.next_page
        end
      end
    end

    def delete!(bucket:, key:)
      storage.delete_object(
        bucket: bucket,
        key: key,
      )

      true
    end

    private

    attr_reader :storage
  end
end
