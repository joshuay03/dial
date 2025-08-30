# frozen_string_literal: true

module Dial
  class Storage
    class MemcachedAdapter
      def initialize options = {}
        raise ArgumentError, "Memcached client required" unless options[:client]

        @client = options[:client]
        @ttl = options[:ttl] || STORAGE_TTL
      end

      def store key, data, ttl: nil
        ttl ||= @ttl
        @client.set (Storage.format_key key), data, ttl
      end

      def fetch key
        @client.get Storage.format_key key
      end

      def delete key
        @client.delete Storage.format_key key
      end
    end
  end
end
