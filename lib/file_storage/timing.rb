# frozen_string_literal: true

module FileStorage
  module Timing
    # "Wall clock is for telling time, monotonic clock is for measuring time."
    #
    # When timing events, ensure we ask for a monotonically adjusted clock time
    # to avoid changes to the system time from being reflected in our
    # measurements.
    #
    # See this article for a good explanation and a deeper dive:
    # https://blog.dnsimple.com/2018/03/elapsed-time-with-ruby-the-right-way/
    #
    # @return [Float]
    def self.monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f
    end
  end
end
