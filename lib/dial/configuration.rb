# frozen_string_literal: true

module Dial
  def self.configure
    yield _configuration
  end

  def self._configuration
    @_configuration ||= Configuration.new
  end

  class Configuration
    def initialize
      @options = {
        sampling_percentage: ::Rails.env.development? ? 100 : 1,
        content_security_policy_nonce: -> (env, _headers) { env[NONCE] || "" },
        vernier_interval: VERNIER_INTERVAL,
        vernier_allocation_interval: VERNIER_ALLOCATION_INTERVAL,
        prosopite_ignore_queries: PROSOPITE_IGNORE_QUERIES,
      }

      @options.keys.each do |key|
        define_singleton_method key do
          @options[key]
        end

        define_singleton_method "#{key}=" do |value|
          @options[key] = value
        end
      end
    end

    def freeze
      @options.freeze

      super
    end
  end
end
