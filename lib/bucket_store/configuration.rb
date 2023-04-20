# frozen_string_literal: true

module BucketStore
  class Configuration
    def logger
      @logger ||= Logger.new($stdout)
    end

    # Specifies a custom logger.
    #
    # Note that {BucketStore} uses structured logging, any custom logger passed must also
    # support it.
    #
    # @example Use stderr as main output device
    #   config.logger = Logger.new($stderr)
    # @!attribute logger
    attr_writer :logger

    def disk_adapter_base_directory
      @disk_adapter_base_directory ||= ENV["DISK_ADAPTER_BASE_DIR"] || Dir.tmpdir
    end

    # Specifies the location of the disk adapter's base directory.
    #
    # If `DISK_ADAPTER_BASE_DIR` is given as an environment variable, its value
    # will be used as a default value. Otherwise this will be equal to the operating
    # system's default temporary file path.
    #
    # @example Create a temporary directory for the disk adapter
    #   config.disk_adapter_base_directory = Dir.mktmpdir
    # @!attribute disk_adapter_base_directory
    attr_writer :disk_adapter_base_directory
  end
end
