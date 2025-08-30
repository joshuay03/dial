# frozen_string_literal: true

module Dial
  class Storage
    class RedisAdapter
      def initialize options = {}
        @client = options[:client]
        @ttl = options[:ttl] || STORAGE_TTL
        raise ArgumentError, "Redis client required" unless @client
      end

      def store key, data, ttl: nil
        ttl ||= @ttl
        @client.setex hashed_key(key), ttl, data
      end

      def fetch key
        @client.get hashed_key(key)
      end

      def delete key
        @client.del hashed_key(key)
      end

      private

      def hashed_key key
        uuid = key.split(":").first
        suffix = key.split(":").last
        "{#{uuid}}:#{suffix}"
      end
    end
  end
end
