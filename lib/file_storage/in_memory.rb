# frozen_string_literal: true

module FileStorage
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

    def list(bucket:, key:)
      matching_keys = @buckets[bucket].keys.select { |k| k.start_with?(key) }
      {
        bucket: bucket,
        keys: matching_keys,
      }
    end
  end
end
