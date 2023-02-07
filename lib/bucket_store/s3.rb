# frozen_string_literal: true

require "uri"

require "aws-sdk-s3"

module BucketStore
  class S3
    DEFAULT_TIMEOUT_SECONDS = 30

    DEFAULT_STREAM_CHUNK_SIZE_BYTES = 1024 * 1024 * 4 # 4Mb

    def self.build(open_timeout_seconds = DEFAULT_TIMEOUT_SECONDS,
                   read_timeout_seconds = DEFAULT_TIMEOUT_SECONDS)
      S3.new(open_timeout_seconds, read_timeout_seconds)
    end

    def initialize(open_timeout_seconds, read_timeout_seconds)
      @storage = Aws::S3::Client.new(
        http_open_timeout: open_timeout_seconds,
        http_read_timeout: read_timeout_seconds,
      )
    end

    def upload!(bucket:, key:, content:)
      storage.put_object(
        bucket: bucket,
        key: key,
        body: content,
      )

      {
        bucket: bucket,
        key: key,
      }
    end

    def download(bucket:, key:)
      file = storage.get_object(
        bucket: bucket,
        key: key,
      )

      {
        bucket: bucket,
        key: key,
        content: file.body.read,
      }
    end

    def stream_download(bucket:, key:, chunk_size: nil)
      chunk_size ||= DEFAULT_STREAM_CHUNK_SIZE_BYTES

      metadata = {
        bucket: bucket,
        key: key,
      }.freeze

      obj_size = storage.head_object(bucket: bucket, key: key)&.content_length || 0

      Enumerator.new do |yielder|
        start = 0
        while start < obj_size
          stop = [start + chunk_size - 1, obj_size].min

          # S3 only supports streaming writes to an IO object (e.g. a file or StringIO),
          # but that means we can't access the content of the downloaded chunk in-memory.
          # Additionally, the block-based support in the sdk also doesn't support retries,
          # which could lead to file corruption.
          # (see https://aws.amazon.com/blogs/developer/downloading-objects-from-amazon-s3-using-the-aws-sdk-for-ruby/)
          #
          # We simulate an enumerator-based streaming approach by using partial range
          # downloads instead. There's no helper methods for range downloads in the Ruby
          # SDK, so we have to build our own range query.
          # Range is specified in the same format as the HTTP range header (see
          # https://www.rfc-editor.org/rfc/rfc9110.html#name-range)
          obj = storage.get_object(
            bucket: bucket,
            key: key,
            range: "bytes=#{start}-#{stop}",
          )

          # rubocop:disable Style/ZeroLengthPredicate
          # StringIO does not define the `.empty?` method that rubocop is so keen on using
          body = obj&.body&.read
          start += body.size
          break if body.nil? || body.size.zero?
          # rubocop:enable Style/ZeroLengthPredicate

          yielder.yield([metadata, body])
        end
      end
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
