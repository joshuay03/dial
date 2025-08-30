# frozen_string_literal: true

require_relative "storage/file_adapter"
require_relative "storage/redis_adapter"
require_relative "storage/memcached_adapter"

module Dial
  class Storage
    SUPPORTED_ADAPTERS = [FileAdapter, RedisAdapter, MemcachedAdapter].freeze

    @mutex = Mutex.new

    class << self
      def validate_key! key
        unless key.match?(/\A.+_vernier:.+\z/)
          raise ArgumentError, "Invalid key format: #{key}. Expected format: '<uuid>_vernier:<suffix>'"
        end
      end

      def extract_uuid key
        validate_key! key
        key.split(":", 2).first
      end

      # Format key for Redis Cluster compatibility (hash tags)
      def format_key key
        uuid = extract_uuid key
        suffix = key.split(":", 2).last
        "{#{uuid}}:#{suffix}"
      end

      def profile_storage_key profile_key
        "#{profile_key}:profile"
      end

      def generate_profile_key
        "#{Util.uuid}_vernier"
      end

      def adapter
        return @adapter if @adapter

        @mutex.synchronize do
          @adapter ||= build_adapter
        end
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
        unless SUPPORTED_ADAPTERS.include? storage_class = config.storage
          raise ArgumentError, "Unsupported storage type: #{storage_class}. Supported adapters: #{SUPPORTED_ADAPTERS.map(&:name).join ', '}"
        end

        storage_class.new config.storage_options
      end
    end
  end
end
