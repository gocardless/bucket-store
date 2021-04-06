# frozen_string_literal: true

require "file_storage/version"
require "file_storage/configuration"
require "file_storage/key_context"
require "file_storage/key_storage"

# An abstraction layer on the top of file cloud storage systems such as Google Cloud
# Storage or S3. This module exposes a generic interface that allows interoperability
# between different storage options. Callers don't need to worry about the specifics
# of where and how a file is stored and retrieved as long as the given key is valid.
#
# Keys within the {FileStorage} are URI strings that can universally locate an object
# in the given provider. A valid key example would be:
# `gs://gc-prd-nx-incoming/file/path.json`.
module FileStorage
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= FileStorage::Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      configuration.logger
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
    def for(key)
      ctx = KeyContext.parse(key)

      KeyStorage.new(adapter: ctx.adapter,
                     bucket: ctx.bucket,
                     key: ctx.key)
    end
  end
end
