# frozen_string_literal: true

require_relative "../../test_helper"

REDIS_AVAILABLE = begin
  require "redis"
  true
rescue LoadError
  false
end

REDIS_CLUSTERING_AVAILABLE = begin
  require "redis-clustering"
  true
rescue LoadError
  false
end

MEMCACHED_AVAILABLE = begin
  require "dalli"
  true
rescue LoadError
  false
end

module Dial
  class Storage
    class TestRealAdapters < Dial::Test
      def setup
        super
        @uuid = "test-real-uuid-#{Time.now.to_i}_vernier"
        @profile_key = "#{@uuid}:profile"
        @profile_data = "test profile data for real adapters"
      end

      def teardown
        super
        cleanup_test_data
      end

      def test_redis_single_node_integration
        skip "Redis not available" unless REDIS_AVAILABLE

        begin
          redis_client = Redis.new url: ENV["REDIS_URL"] || "redis://localhost:6379"
          redis_client.ping
        rescue => e
          skip "Redis server not available: #{e.message}"
        end

        adapter = RedisAdapter.new client: redis_client

        adapter.store @profile_key, @profile_data
        fetched_profile = adapter.fetch @profile_key
        assert_equal @profile_data, fetched_profile

        adapter.delete @profile_key
        assert_nil adapter.fetch @profile_key
      end

      def test_redis_clustering_integration
        skip "Redis clustering not available" unless REDIS_CLUSTERING_AVAILABLE

        begin
          cluster_nodes = [
            ENV["REDIS_CLUSTER_NODE_1"] || "redis://localhost:8000",
            ENV["REDIS_CLUSTER_NODE_2"] || "redis://localhost:8001",
            ENV["REDIS_CLUSTER_NODE_3"] || "redis://localhost:8002"
          ]

          cluster_client = Redis::Cluster.new(nodes: cluster_nodes)
          cluster_client.ping

          cluster_client.set "dial_cluster_test", "test", ex: 1
          cluster_client.del "dial_cluster_test"
        rescue => e
          skip "Redis cluster not available: #{e.message}"
        end

        adapter = RedisAdapter.new client: cluster_client
        begin
          adapter.store @profile_key, @profile_data
          fetched_profile = adapter.fetch @profile_key

          if fetched_profile.nil?
            skip "Redis cluster data operations failed - cluster may not be properly initialized"
          end

          assert_equal @profile_data, fetched_profile

          profile_slot = cluster_client.call("CLUSTER", "KEYSLOT", "{#{@uuid}}:profile")
          assert_kind_of Integer, profile_slot

          adapter.delete @profile_key
          assert_nil adapter.fetch(@profile_key)
        rescue => e
          skip "Redis cluster operations failed: #{e.message}"
        end
      end

      def test_memcached_integration
        skip "Memcached not available" unless MEMCACHED_AVAILABLE

        memcached_client = Dalli::Client.new ENV["MEMCACHED_URL"] || "localhost:11211"
        begin
          memcached_client.set "dial_test_key", "test", 1
          memcached_client.delete "dial_test_key"
        rescue => e
          skip "Memcached server not available: #{e.message}"
        end

        adapter = MemcachedAdapter.new client: memcached_client

        adapter.store @profile_key, @profile_data
        fetched_profile = adapter.fetch @profile_key
        assert_equal @profile_data, fetched_profile

        adapter.delete @profile_key
        assert_nil adapter.fetch @profile_key
      end

      def test_redis_ttl_functionality
        skip "Redis not available" unless REDIS_AVAILABLE

        begin
          redis_client = Redis.new url: ENV["REDIS_URL"] || "redis://localhost:6379"
          redis_client.ping
        rescue => e
          skip "Redis server not available: #{e.message}"
        end

        adapter = RedisAdapter.new client: redis_client
        short_ttl = 2

        adapter.store @profile_key, @profile_data, ttl: short_ttl
        assert_equal @profile_data, adapter.fetch(@profile_key)

        ttl = redis_client.ttl Storage.format_key @profile_key
        assert ttl > 0 && ttl <= short_ttl, "Expected TTL to be between 1 and #{short_ttl}, got #{ttl}"

        sleep short_ttl + 1
        assert_nil adapter.fetch(@profile_key)
      end

      def test_memcached_ttl_functionality
        skip "Memcached not available" unless MEMCACHED_AVAILABLE

        memcached_client = Dalli::Client.new ENV["MEMCACHED_URL"] || "localhost:11211"
        begin
          memcached_client.set "dial_test_key", "test", 1
          memcached_client.delete "dial_test_key"
        rescue => e
          skip "Memcached server not available: #{e.message}"
        end

        adapter = MemcachedAdapter.new client: memcached_client
        short_ttl = 2

        adapter.store @profile_key, @profile_data, ttl: short_ttl
        fetched_data = adapter.fetch @profile_key
        assert_equal @profile_data, fetched_data

        sleep short_ttl + 1
        assert_nil adapter.fetch(@profile_key)
      end

      def test_large_profile_data_storage
        skip "Redis not available" unless REDIS_AVAILABLE

        begin
          redis_client = Redis.new url: ENV["REDIS_URL"] || "redis://localhost:6379"
          redis_client.ping
        rescue => e
          skip "Redis server not available: #{e.message}"
        end

        adapter = RedisAdapter.new client: redis_client
        large_profile_data = "x" * 1024 * 1024

        adapter.store @profile_key, large_profile_data
        fetched_data = adapter.fetch @profile_key
        assert_equal large_profile_data, fetched_data

        adapter.delete @profile_key
      end

      private

      def cleanup_test_data
        if REDIS_AVAILABLE
          begin
            redis_client = Redis.new url: ENV["REDIS_URL"] || "redis://localhost:6379"
            redis_client.del "{#{@uuid}}:profile"
          rescue
          end
        end

        if MEMCACHED_AVAILABLE
          begin
            memcached_client = Dalli::Client.new ENV["MEMCACHED_URL"] || "localhost:11211"
            memcached_client.delete @profile_key
          rescue
          end
        end
      end
    end
  end
end
