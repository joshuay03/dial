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
        enabled: true,
        force_param: FORCE_PARAM,
        sampling_percentage: ::Rails.env.development? ? SAMPLING_PERCENTAGE_DEV : SAMPLING_PERCENTAGE_PROD,
        storage: Storage::FileAdapter,
        storage_options: { ttl: STORAGE_TTL },
        content_security_policy_nonce: -> env, _headers { env[NONCE] || EMPTY_NONCE },
        toggle_shortcut_keys: TOGGLE_SHORTCUT_KEYS,
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
