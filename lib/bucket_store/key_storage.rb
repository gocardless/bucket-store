# frozen_string_literal: true

require "bucket_store/timing"
require "bucket_store/in_memory"
require "bucket_store/gcs"
require "bucket_store/s3"
require "bucket_store/disk"

module BucketStore
  class KeyStorage
    SUPPORTED_ADAPTERS = {
      gs: Gcs,
      s3: S3,
      inmemory: InMemory,
      disk: Disk,
    }.freeze

    # Defines a streaming interface for download and upload operations.
    #
    # Note that individual adapters may require additional configuration for the correct
    # behavior of the streaming interface.
    class KeyStreamer
      attr_reader :bucket, :key, :adapter

      def initialize(adapter:, bucket:, key:)
        @adapter = adapter
        @bucket = bucket
        @key = key
      end

      # Streams the content of the reference key
      #
      # @param [optional, Integer] chunk_size The maximum size of individual chunks.
      #   Note that adapters will only return at most the given size, but could
      #   return a smaller chunk when needed.
      #
      # @return [Enumerator]
      #   An enumerator where each item is a hash that includes a chunk of the downloaded result.
      #   The format of the hash returned on each iteration is compatible with what is returned by
      #   the non-streaming version of the `download` method, however the content of each item is
      #   limited in size.
      #
      # @see KeyStorage#download
      # @example Download a key
      #   BucketStore.for("inmemory://bucket/file.xml").stream.download
      def download(chunk_size: nil)
        if !chunk_size.nil? && chunk_size <= 0
          raise ArgumentError, "Chunk size must be > 0 when specified"
        end

        BucketStore.logger.info(event: "key_storage.stream.download_started")

        start = BucketStore::Timing.monotonic_now
        result = adapter.stream_download(
          bucket: bucket,
          key: key,
          chunk_size: chunk_size,
        )

        BucketStore.logger.info(event: "key_storage.stream.download_prepared",
                                duration: BucketStore::Timing.monotonic_now - start)

        result
      end

      class StreamUploader
        def initialize(uploader)
          @uploader = uploader
        end

        def upload!(content)
          if content.nil?
            raise ArgumentError, "Content must be a valid string"
          end

          puts @uploader
          @uploader.call(content)
        end

        def complete
          @uploader.finish
        end
      end

      def upload
        BucketStore.logger.info(event: "key_storage.stream.upload_started")

        start = BucketStore::Timing.monotonic_now
        uploader = StreamUploader.new(adapter.stream_upload(
                                   bucket: bucket,
                                   key: key,
                                 ))
        yield uploader
        uploader.finish

        BucketStore.logger.info(event: "key_storage.stream.upload_finished",
                                duration: BucketStore::Timing.monotonic_now - start)

        # should be returned by the adapter
        {
          bucket: bucket,
          key: key,
        }
      end
    end

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
    #   BucketStore.for("inmemory://bucket/file.xml").download
    def download
      raise ArgumentError, "Key cannot be empty" if key.empty?

      BucketStore.logger.info(event: "key_storage.download_started")

      start = BucketStore::Timing.monotonic_now
      result = adapter.download(bucket: bucket, key: key)

      BucketStore.logger.info(event: "key_storage.download_finished",
                              duration: BucketStore::Timing.monotonic_now - start)

      result
    end

    # Returns an interface for streaming operations
    #
    # @return [KeyStreamer] An interface for streaming operations
    def stream
      raise ArgumentError, "Key cannot be empty" if key.empty?

      KeyStreamer.new(adapter: adapter, bucket: bucket, key: key)
    end

    # Uploads the given content to the reference key location.
    #
    # If the `key` already exists, its content will be replaced by the one in input.
    #
    # @param [String] content The content to upload
    # @return [String] The final `key` where the content has been uploaded
    # @example Upload a file
    #   BucketStore.for("inmemory://bucket/file.xml").upload("hello world")
    def upload!(content)
      raise ArgumentError, "Key cannot be empty" if key.empty?

      BucketStore.logger.info(event: "key_storage.upload_started",
                              **log_context)

      start = BucketStore::Timing.monotonic_now
      result = adapter.upload!(
        bucket: bucket,
        key: key,
        content: content,
      )

      BucketStore.logger.info(event: "key_storage.upload_finished",
                              duration: BucketStore::Timing.monotonic_now - start,
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
      BucketStore.logger.info(event: "key_storage.list_started")

      start = BucketStore::Timing.monotonic_now
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

          BucketStore.logger.info(
            event: "key_storage.list_page_fetched",
            resource_count: keys.count,
            page: page_count,
            duration: BucketStore::Timing.monotonic_now - start,
          )

          keys.each do |key|
            yielder.yield(key)
          end
        end
      end
    end

    # Deletes the referenced key.
    #
    # Note that this method will always return true.
    #
    # @return [bool]
    #
    # @example Delete a file
    #   BucketStore.for("inmemory://bucket/file.txt").delete!
    def delete!
      BucketStore.logger.info(event: "key_storage.delete_started")

      start = BucketStore::Timing.monotonic_now
      adapter.delete!(bucket: bucket, key: key)

      BucketStore.logger.info(event: "key_storage.delete_finished",
                              duration: BucketStore::Timing.monotonic_now - start)

      true
    end

    # Checks if the given key exists.
    #
    # This will only return true when the `key` exactly matches an object within the bucket
    # and conversely it will return false when `key` matches an internal path to an object.
    # For example if the bucket has a key named `prefix/file.txt`, it will only return
    # `true` when `exists?` is called on `prefix/file.txt`. Any other combination
    # (`prefix/`, `prefix/file`) will instead return `false`.
    #
    # @return [bool] `true` if the given key exists, `false` if not
    def exists?
      list(page_size: 1).first == "#{adapter_type}://#{bucket}/#{key}"
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
