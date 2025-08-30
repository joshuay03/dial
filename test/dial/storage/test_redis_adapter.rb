# frozen_string_literal: true

require_relative "../../test_helper"

module Dial
  class Storage
    class TestRedisAdapter < Dial::Test
      def setup
        super
        @mock_client = Minitest::Mock.new
        @adapter = RedisAdapter.new client: @mock_client
        @uuid = "test-uuid-123_vernier"
        @profile_key = "#{@uuid}:profile"
        @profile_data = "test profile data"
      end

      def test_store_profile
        hashed_key = "{#{@uuid}}:profile"
        @mock_client.expect :setex, "OK", [hashed_key, STORAGE_TTL, @profile_data]

        @adapter.store @profile_key, @profile_data
        @mock_client.verify
      end

      def test_store_with_custom_ttl
        hashed_key = "{#{@uuid}}:profile"
        custom_ttl = 7200
        @mock_client.expect :setex, "OK", [hashed_key, custom_ttl, @profile_data]

        @adapter.store @profile_key, @profile_data, ttl: custom_ttl
        @mock_client.verify
      end

      def test_fetch_profile
        hashed_key = "{#{@uuid}}:profile"
        @mock_client.expect :get, @profile_data, [hashed_key]

        result = @adapter.fetch @profile_key
        assert_equal @profile_data, result
        @mock_client.verify
      end

      def test_fetch_nonexistent_key
        hashed_key = "{#{@uuid}}:profile"
        @mock_client.expect :get, nil, [hashed_key]

        result = @adapter.fetch @profile_key
        assert_nil result
        @mock_client.verify
      end

      def test_delete
        hashed_key = "{#{@uuid}}:profile"
        @mock_client.expect :del, 1, [hashed_key]

        @adapter.delete @profile_key
        @mock_client.verify
      end

      def test_store_propagates_redis_error
        def @mock_client.setex(key, ttl, value)
          raise "Connection failed"
        end

        error = assert_raises StandardError do
          @adapter.store @profile_key, @profile_data
        end
        assert_equal "Connection failed", error.message
      end

      def test_fetch_propagates_redis_error
        def @mock_client.get(key)
          raise "Connection failed"
        end

        error = assert_raises StandardError do
          @adapter.fetch @profile_key
        end
        assert_equal "Connection failed", error.message
      end

      def test_delete_propagates_redis_error
        def @mock_client.del(key)
          raise "Connection failed"
        end

        error = assert_raises StandardError do
          @adapter.delete @profile_key
        end
        assert_equal "Connection failed", error.message
      end

      def test_hashed_key_generation
        hashed_key = Storage.format_key "test-123_vernier:profile"
        assert_equal "{test-123_vernier}:profile", hashed_key

        hashed_key = Storage.format_key "another-uuid_vernier:profile"
        assert_equal "{another-uuid_vernier}:profile", hashed_key
      end

      def test_initialization_requires_client
        assert_raises ArgumentError do
          RedisAdapter.new
        end

        assert_raises ArgumentError do
          RedisAdapter.new client: nil
        end
      end

      def test_cluster_hash_tags_preserve_uuid
        profile_key = Storage.format_key "test-uuid_vernier:profile"

        assert_equal "{test-uuid_vernier}:profile", profile_key

        profile_hash_slot = profile_key.match(/\{([^}]+)\}/)[1]
        assert_equal "test-uuid_vernier", profile_hash_slot
      end

      def test_different_uuids_can_use_different_slots
        key1 = Storage.format_key "uuid1_vernier:profile"
        key2 = Storage.format_key "uuid2_vernier:profile"

        assert_equal "{uuid1_vernier}:profile", key1
        assert_equal "{uuid2_vernier}:profile", key2
      end

      def test_propagates_redis_cluster_connection_errors
        def @mock_client.setex(key, ttl, value)
          raise "Cluster connection failed"
        end

        error = assert_raises StandardError do
          @adapter.store @profile_key, @profile_data
        end
        assert_equal "Cluster connection failed", error.message
      end

      def test_propagates_redis_cluster_command_errors
        def @mock_client.get(key)
          raise "MOVED 1234 127.0.0.1:7002"
        end

        error = assert_raises StandardError do
          @adapter.fetch @profile_key
        end
        assert_equal "MOVED 1234 127.0.0.1:7002", error.message
      end
    end
  end
end
