# frozen_string_literal: true

require "uri"

module BucketStore
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
      uri = URI(escape(raw_key))

      scheme = unescape(uri.scheme)
      bucket = unescape(uri.host)

      # A key should never be `nil` but can be empty. Depending on the operation, this may
      # or may not be a valid configuration (e.g. an empty key is likely valid on a
      # `list`, but not during a `download`).
      key = unescape(uri.path).sub!(%r{/}, "") || ""

      raise KeyParseException if [scheme, bucket, key].map(&:nil?).any?

      KeyContext.new(adapter: scheme,
                     bucket: bucket,
                     key: key)
    end

    def self.escape(key)
      return key if key.nil?

      URI::DEFAULT_PARSER.escape(key)
    end
    private_class_method :escape

    def self.unescape(key)
      return key if key.nil?

      URI::DEFAULT_PARSER.unescape(key)
    end
    private_class_method :unescape
  end
end
