# frozen_string_literal: true

require "bucket_store/version"
require "bucket_store/configuration"
require "bucket_store/key_context"
require "bucket_store/key_storage"
require "bucket_store/uri_builder"

# An abstraction layer on the top of file cloud storage systems such as Google Cloud
# Storage or S3. This module exposes a generic interface that allows interoperability
# between different storage options. Callers don't need to worry about the specifics
# of where and how a file is stored and retrieved as long as the given key is valid.
#
# Keys within the {BucketStore} are URI strings that can universally locate an object
# in the given provider. A valid key example would be:
# `gs://gcs-bucket/file/path.json`.
module BucketStore
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= BucketStore::Configuration.new
    end

    # Yields a {BucketStore::Configuration} object that allows callers to configure
    # BucketStore's behaviour.
    #
    # @yield [BucketStore::Configuration]
    #
    # @example Configure BucketStore to use a different logger than the default
    #   BucketStore.configure do |config|
    #     config.logger = Logger.new($stderr)
    #   end
    def configure
      yield(configuration)
    end

    def logger
      configuration.logger
    end

    # Given a `key` in the format of `adapter://bucket/key` returns the corresponding
    # adapter that will allow to manipulate (e.g. download, upload or list) such key.
    #
    # Currently supported adapters are `gs` (Google Cloud Storage), `s3` (AWS S3),
    # `inmemory` (an in-memory key-value storage) and `disk` (a disk-backed key-value store).
    #
    # @param [String] key The reference key
    # @return [KeyStorage] An interface to the adapter that can handle requests on the given key
    # @example Configure {BucketStore} for Google Cloud Storage
    #   BucketStore.for("gs://the_bucket/a/valid/key")
    def for(key)
      ctx = KeyContext.parse(key)

      KeyStorage.new(adapter: ctx.adapter,
                     bucket: ctx.bucket,
                     key: ctx.key)
    end
  end
end
