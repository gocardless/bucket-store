# frozen_string_literal: true

require "loggy"

module FileStorage
  module Logger
    def logger
      Loggy.logger.with(
        class: self.class.name,
        object_id: object_id,
        **log_context,
      )
    end

    def log_context
      {}
    end

    def self.included(base)
      base.extend(self)
      base.define_singleton_method(:logger_class) { name }
    end

    delegate :fatal, :error, :warn, :info, :debug, :unknown, to: :logger

    alias_method :log, :info
  end
end
