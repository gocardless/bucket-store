# frozen_string_literal: true

require "file_storage/version"
require "file_storage/configuration"
require "file_storage/file_storage"

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
  end
end
