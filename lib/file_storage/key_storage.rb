# frozen_string_literal: true

require "file_storage/timing"
require "file_storage/in_memory"
require "file_storage/gcs"
require "file_storage/disk"

module FileStorage
  class KeyStorage
    SUPPORTED_ADAPTERS = {
      gs: Gcs,
      inmemory: InMemory,
      disk: Disk,
    }.freeze

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
    # @return [Hash<Symbol, Object>]
    #   A hash that includes the download result. The hash keys reference different aspects of the
    #   download (e.g. `:key` and `:content` will include respectively the original key's name and
    #   the actual download's content)
    #
    # @example Download a key
    #   FileStorage.for("inmemory://bucket/file.xml").download
    def download
      raise ArgumentError, "Key cannot be empty" if key.empty?

      FileStorage.logger.info(event: "key_storage.download_started")

      start = FileStorage::Timing.monotonic_now
      result = adapter.download(bucket: bucket, key: key)

      FileStorage.logger.info(event: "key_storage.download_finished",
                              duration: FileStorage::Timing.monotonic_now - start)

      result
    end

    # Uploads the given content to the reference key location.
    #
    # If the `key` already exists, its content will be replaced by the one in input.
    #
    # @param [String] content The content to upload
    # @return [String] The final `key` where the content has been uploaded
    # @example Upload a file
    #   FileStorage.for("inmemory://bucket/file.xml").upload("hello world")
    def upload!(content)
      raise ArgumentError, "Key cannot be empty" if key.empty?

      FileStorage.logger.info(event: "key_storage.upload_started",
                              **log_context)

      start = FileStorage::Timing.monotonic_now
      result = adapter.upload!(
        bucket: bucket,
        key: key,
        content: content,
      )

      FileStorage.logger.info(event: "key_storage.upload_finished",
                              duration: FileStorage::Timing.monotonic_now - start,
                              **log_context)

      "#{adapter_type}://#{result[:bucket]}/#{result[:key]}"
    end

    # Lists all keys for the current adapter that have the reference key as prefix
    #
    # This will return a list of valid keys in the format of `adapter://bucket/key`. The keys in
    # the list will share the reference key as a prefix.
    #
    # @param [Integer] page_size
    #   the number of items to be returned in the call. Note that if the `page_size` is
    #   smaller than the available keys for the given URI, there's no guarantee on the
    #   ordering upon which the keys will be returned and it's possible for two calls on
    #   the same URI and same `page_size` to return different result sets.
    # @return [Array<String>] A list of keys in the format of `adapter://bucket/key`
    #
    # @example List all files under a given prefix
    #   FileStorage.for("inmemory://bucket/prefix").list
    def list(page_size: 1000)
      FileStorage.logger.info(event: "key_storage.list_started")

      start = FileStorage::Timing.monotonic_now
      result = adapter.list(
        bucket: bucket,
        key: key,
        page_size: page_size,
      )

      FileStorage.logger.info(resource_count: result[:keys].count,
                              event: "key_storage.list_finished",
                              duration: FileStorage::Timing.monotonic_now - start)

      result[:keys].map { |key| "#{adapter_type}://#{result[:bucket]}/#{key}" }
    end

    # Deletes the referenced key.
    #
    # Note that this method will always return true.
    #
    # @return [bool]
    #
    # @example Delete a file
    #   FileStorage.for("inmemory://bucket/file.txt").delete!
    def delete!
      FileStorage.logger.info(event: "key_storage.delete_started")

      start = FileStorage::Timing.monotonic_now
      adapter.delete!(bucket: bucket, key: key)

      FileStorage.logger.info(event: "key_storage.delete_finished",
                              duration: FileStorage::Timing.monotonic_now - start)

      true
    end

    private

    attr_reader :adapter

    def log_context
      {
        bucket: bucket,
        key: key,
        adapter_type: adapter_type,
      }.compact
    end
  end
end
