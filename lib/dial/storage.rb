# frozen_string_literal: true

require_relative "storage/file_adapter"
require_relative "storage/redis_adapter"
require_relative "storage/memcached_adapter"

module Dial
  class Storage
    SUPPORTED_ADAPTERS = [FileAdapter, RedisAdapter, MemcachedAdapter].freeze

    class << self
      def adapter
        @adapter ||= build_adapter
      end

      def store key, data, ttl: nil
        adapter.store key, data, ttl: ttl
      end

      def fetch key
        adapter.fetch key
      end

      def delete key
        adapter.delete key
      end

      def cleanup
        adapter.cleanup if adapter.respond_to? :cleanup
      end

      private

      def build_adapter
        config = Dial._configuration
        storage_class = config.storage

        unless SUPPORTED_ADAPTERS.include? storage_class
          raise ArgumentError, "Unsupported storage type: #{storage_class}. Supported adapters: #{SUPPORTED_ADAPTERS.map(&:name).join ', '}"
        end

        storage_class.new config.storage_options
      end
    end
  end
end
