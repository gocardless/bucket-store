# frozen_string_literal: true

module FileStorage
  class Configuration
    def logger
      @logger ||= Logger.new($stdout)
    end

    # Specifies a custom logger.
    #
    # Note that {FileStorage} uses structured logging, any custom logger passed must also
    # support it.
    #
    # @example Use stderr as main output device
    #   config.logger = Logger.new($stderr)
    # @!attribute logger
    attr_writer :logger
  end
end
