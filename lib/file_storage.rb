# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/string/access"

require "uri"
require "values"

require "file_storage/version"
require "file_storage/timing"
require "file_storage/logger"
require "file_storage/in_memory"
require "file_storage/gcs"
require "file_storage/disk"

# An abstraction layer on the top of file cloud storage systems such as Google Cloud
# Storage or S3. This module exposes a generic interface that allows interoperability
# between different storage options. Callers don't need to worry about the specifics
# of where and how a file is stored and retrieved as long as the given key is valid.
#
# Keys within the {FileStorage} are URI strings that can universally locate an object
# in the given provider. A valid key example would be:
# `gs://gc-prd-nx-incoming/file/path.json`.
module FileStorage
  SUPPORTED_ADAPTERS = {
    gs: Gcs,
    inmemory: InMemory,
    disk: Disk,
  }.freeze

  class KeyCtx < Value.new(:adapter, :bucket, :key)
    def to_s
      "<KeyCtx adapter:#{adapter} bucket:#{bucket} key:#{key}>"
    end

    def self.parse(raw_key)
      uri = URI(raw_key)

      KeyCtx.with(adapter: uri.scheme,
                  bucket: uri.host,
                  key: uri.path.sub!(%r{/}, ""))
    end
  end

  # Given a `key` in the format of `adapter://bucket/key` returns the corresponding
  # adapter that will allow to manipulate (e.g. download, upload or list) such key.
  #
  # Currently supported adapters are `gs` (Google Cloud Storage), `inmemory` (an
  # in-memory key-value storage) and `disk` (a disk-backed key-value store).
  #
  # @param [String] key The reference key
  # @return [KeyStorage] An interface to the adapter that can handle requests on the given key
  # @example Configure {FileStorage} for Google Cloud Storage
  #   FileStorage.for("gs://the_bucket/a/valid/key")
  def self.for(key)
    ctx = KeyCtx.parse(key)

    KeyStorage.new(adapter: ctx.adapter,
                   bucket: ctx.bucket,
                   key: ctx.key)
  end

  # Sanitizes the input as not all characters are valid as either URIs or as bucket keys.
  # When we get them we want to replace them with something FileStorage can process.
  #
  # @param input [String]
  # @return [String]
  def self.sanitize(input)
    input.gsub(/[{}<>]/, "__")
  end

  class KeyStorage
    include FileStorage::Logger

    attr_reader :bucket, :key, :adapter_type

    def initialize(adapter:, bucket:, key:)
      @adapter_type = adapter.to_sym
      raise "Unknown adapter: #{@adapter_type}" unless SUPPORTED_ADAPTERS.include?(@adapter_type)

      @adapter = SUPPORTED_ADAPTERS.fetch(@adapter_type).build
      @bucket = bucket
      @key = key
    end

    def filename
      File.basename(key)
    end

    # Downloads the content of the reference key
    #
    # @return [Hash{Symbol => Object}
    #   A hash that includes the download result. The hash keys reference different aspects of the
    #   download (e.g. `:key` and `:content` will include respectively the original key's name and
    #   the actual download's content)
    def download
      info("Downloading #{key}...",
           event: "key_storage.download_started")

      start = FileStorage::Timing.monotonic_now
      result = adapter.download(bucket: bucket, key: key)

      info("Download of #{key} completed",
           event: "key_storage.download_finished",
           duration: FileStorage::Timing.monotonic_now - start)

      result
    end

    # Uploads the given content to the reference key location.
    #
    # If the `key` already exists, its content will be replaced by the one in input.
    #
    # @param [String] content The content to upload
    # @return [String] The final `key` where the content has been uploaded
    def upload!(content)
      info("Uploading #{key}...",
           event: "key_storage.upload_started")

      start = FileStorage::Timing.monotonic_now
      result = adapter.upload!(
        bucket: bucket,
        key: key,
        content: content,
      )

      info("Upload of #{key} completed",
           event: "key_storage.upload_finished",
           duration: FileStorage::Timing.monotonic_now - start)

      "#{adapter_type}://#{result[:bucket]}/#{result[:key]}"
    end

    # Lists all keys for the current adapter that have the reference key as prefix
    #
    # This will return a list of valid keys in the format of `adapter://bucket/key`. The keys in
    # the list will share the reference key as a prefix.
    #
    # @return [Array<String>] A list of keys in the format of `adapter://bucket/key`
    def list
      info("Listing using #{key} as prefix",
           event: "key_storage.list_started")

      start = FileStorage::Timing.monotonic_now
      result = adapter.list(
        bucket: bucket,
        key: key,
      )

      info("Listing of #{key} completed",
           resource_count: result[:keys].count,
           event: "key_storage.list_finished",
           duration: FileStorage::Timing.monotonic_now - start)

      result[:keys].map { |key| "#{adapter_type}://#{result[:bucket]}/#{key}" }
    end

    private

    attr_reader :adapter

    def log_context
      {
        bucket: bucket,
        key: key,
        adapter_type: adapter_type,
      }
    end
  end
end
