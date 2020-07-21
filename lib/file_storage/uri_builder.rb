# frozen_string_literal: true

module FileStorage
  module UriBuilder
    # Sanitizes the input as not all characters are valid as either URIs or as bucket keys.
    # When we get them we want to replace them with something Nexus can process.
    #
    # @param input [String] the string to sanitise
    # @param [String] replacement the replacement string for invalid characters
    # @return [String] the sanitised string
    def self.sanitize(input, replacement = "__")
      input.gsub(/[{}<>]/, replacement)
    end
  end
end
