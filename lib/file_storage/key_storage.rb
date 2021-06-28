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
    # Internally, this method will paginate through the result set. The default page size
    # for the underlying adapter can be controlled via the `page_size` argument.
    #
    # This will return a enumerator of valid keys in the format of `adapter://bucket/key`.
    # The keys in the list will share the reference key as a prefix. Underlying adapters will
    # paginate the result set as the enumerable is consumed. The number of items per page
    # can be controlled by the `page_size` argument.
    #
    # @param [Integer] page_size
    #   the max number of items to fetch for each page of results
    def list(page_size: 1000)
      FileStorage.logger.info(event: "key_storage.list_started")

      start = FileStorage::Timing.monotonic_now
      pages = adapter.list(
        bucket: bucket,
        key: key,
        page_size: page_size,
      )

      page_count = 0
      Enumerator.new do |yielder|
        pages.each do |page|
          page_count += 1
          keys = page.fetch(:keys, []).map { |key| "#{adapter_type}://#{page[:bucket]}/#{key}" }

          FileStorage.logger.info(
            event: "key_storage.list_page_fetched",
            resource_count: keys.count,
            page: page_count,
            duration: FileStorage::Timing.monotonic_now - start,
          )

          keys.each do |key|
            yielder.yield(key)
          end
        end
      end
    end

    # Moves the existing file to a new file path
    #
    # @param [String] new_key The new key to move the file to
    # @return [String] A URI to the file's new path
    # @example Move a file
    #   FileStorage.for("inmemory://bucket1/foo").move!("inmemory://bucket2/bar")
    def move!(new_key)
      raise ArgumentError, "Key cannot be empty" if key.empty?

      new_key_ctx = FileStorage.for(new_key)

      unless new_key_ctx.adapter_type == adapter_type
        raise ArgumentError, "Adapter type must be the same"
      end
      raise ArgumentError, "Destination key cannot be empty" if new_key_ctx.key.empty?

      start = FileStorage::Timing.monotonic_now
      result = adapter.move!(
        bucket: bucket,
        key: key,
        new_bucket: new_key_ctx.bucket,
        new_key: new_key_ctx.key,
      )

      old_key = "#{adapter_type}://#{bucket}/#{key}"
      new_key = "#{adapter_type}://#{result[:bucket]}/#{result[:key]}"

      FileStorage.logger.info(
        event: "key_storage.moved",
        duration: FileStorage::Timing.monotonic_now - start,
        old_key: old_key,
        new_key: new_key,
      )

      new_key
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
