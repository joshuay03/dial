# frozen_string_literal: true

module Dial
  class Storage
    class MemcachedAdapter
      def initialize options = {}
        @client = options[:client]
        @ttl = options[:ttl] || STORAGE_TTL
        raise ArgumentError, "Memcached client required" unless @client
      end

      def store key, data, ttl: nil
        ttl ||= @ttl
        @client.set key, data, ttl
      end

      def fetch key
        @client.get key
      end

      def delete key
        @client.delete key
      end
    end
  end
end
