# frozen_string_literal: true

require_relative "../../test_helper"

module Dial
  class Storage
    class TestMemcachedAdapter < Dial::Test
      def setup
        super
        @mock_client = Minitest::Mock.new
        @adapter = MemcachedAdapter.new client: @mock_client
        @uuid = "test-uuid-123_vernier"
        @profile_key = "#{@uuid}:profile"
        @profile_data = "test profile data"
      end

      def test_store_profile
        hashed_key = "{#{@uuid}}:profile"
        @mock_client.expect :set, "STORED", [hashed_key, @profile_data, STORAGE_TTL]

        @adapter.store @profile_key, @profile_data
        @mock_client.verify
      end

      def test_store_with_custom_ttl
        custom_ttl = 7200
        hashed_key = "{#{@uuid}}:profile"
        @mock_client.expect :set, "STORED", [hashed_key, @profile_data, custom_ttl]

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
        @mock_client.expect :delete, true, [hashed_key]

        @adapter.delete @profile_key
        @mock_client.verify
      end

      def test_store_propagates_memcached_error
        def @mock_client.set(key, value, ttl)
          raise "Connection failed"
        end

        error = assert_raises StandardError do
          @adapter.store @profile_key, @profile_data
        end
        assert_equal "Connection failed", error.message
      end

      def test_fetch_propagates_memcached_error
        def @mock_client.get(key)
          raise "Connection failed"
        end

        error = assert_raises StandardError do
          @adapter.fetch @profile_key
        end
        assert_equal "Connection failed", error.message
      end

      def test_delete_propagates_memcached_error
        def @mock_client.delete(key)
          raise "Connection failed"
        end

        error = assert_raises StandardError do
          @adapter.delete @profile_key
        end
        assert_equal "Connection failed", error.message
      end

      def test_initialization_requires_client
        assert_raises ArgumentError do
          MemcachedAdapter.new
        end

        assert_raises ArgumentError do
          MemcachedAdapter.new client: nil
        end
      end
    end
  end
end
