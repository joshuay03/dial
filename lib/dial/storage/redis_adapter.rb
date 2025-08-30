# frozen_string_literal: true

module Dial
  class Storage
    class RedisAdapter
      def initialize options = {}
        raise ArgumentError, "Redis client required" unless options[:client]

        @client = options[:client]
        @ttl = options[:ttl] || STORAGE_TTL
      end

      def store key, data, ttl: nil
        ttl ||= @ttl
        @client.setex (Storage.format_key key), ttl, data
      end

      def fetch key
        @client.get Storage.format_key key
      end

      def delete key
        @client.del Storage.format_key key
      end
    end
  end
end
