# frozen_string_literal: true

require "uri"

module FileStorage
  class KeyContext
    attr_reader :adapter, :bucket, :key

    class KeyParseException < RuntimeError; end

    def initialize(adapter:, bucket:, key:)
      @adapter = adapter
      @bucket = bucket
      @key = key
    end

    def to_s
      "<KeyContext adapter:#{adapter} bucket:#{bucket} key:#{key}>"
    end

    def self.parse(raw_key)
      uri = URI(raw_key)

      # A key should never be `nil` but can be empty. Depending on the operation, this may
      # or may not be a valid configuration (e.g. an empty key is likely valid on a
      # `list`, but not during a `download`).
      key = uri.path.sub!(%r{/}, "") || ""

      raise KeyParseException if [uri.scheme, uri.host, key].map(&:nil?).any?

      KeyContext.new(adapter: uri.scheme,
                     bucket: uri.host,
                     key: key)
    end
  end
end
