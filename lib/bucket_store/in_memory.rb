# frozen_string_literal: true

module BucketStore
  class InMemory
    DEFAULT_STREAM_CHUNK_SIZE_BYTES = 1024 * 1024 * 4 # 4Mb

    def self.build
      InMemory.instance
    end

    def self.instance
      # rubocop:disable Style/ClassVars
      @@instance ||= new
      # rubocop:enable Style/ClassVars
    end

    def self.reset!
      instance.reset!
    end

    def initialize
      reset!
    end

    def reset!
      @buckets = Hash.new { |hash, key| hash[key] = {} }
    end

    def upload!(bucket:, key:, content:)
      @buckets[bucket][key] = content

      {
        bucket: bucket,
        key: key,
      }
    end

    def download(bucket:, key:)
      {
        bucket: bucket,
        key: key,
        content: @buckets[bucket].fetch(key),
      }
    end

    def stream_download(bucket:, key:, chunk_size: nil)
      chunk_size ||= DEFAULT_STREAM_CHUNK_SIZE_BYTES

      content_stream = StringIO.new(@buckets[bucket].fetch(key))
      metadata = {
        bucket: bucket,
        key: key,
      }.freeze

      Enumerator.new do |yielder|
        loop do
          v = content_stream.read(chunk_size)
          break if v.nil?

          yielder.yield([metadata, v])
        end
      end
    end

    def stream_upload(bucket:, key:)
      @buckets[bucket][key] = ""
      proc do |content|
        @buckets[bucket][key] += content
      end
    end

    def list(bucket:, key:, page_size:)
      @buckets[bucket].keys.
        select { |k| k.start_with?(key) }.
        each_slice(page_size).
        map do |keys|
          {
            bucket: bucket,
            keys: keys,
          }
        end.to_enum
    end

    def delete!(bucket:, key:)
      @buckets[bucket].delete(key)

      true
    end
  end
end
