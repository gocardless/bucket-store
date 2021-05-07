# frozen_string_literal: true

module BucketStore
  class InMemory
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

    # rubocop: disable Lint/UnusedMethodArgument
    def presigned_url(bucket:, key:, expiry:)
      "inmemory://#{bucket}/#{key}"
    end
    # rubocop: enable Lint/UnusedMethodArgument
  end
end
