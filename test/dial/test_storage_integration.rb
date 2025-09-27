# frozen_string_literal: true

require_relative "../test_helper"

module Dial
  class TestStorageIntegration < Dial::Test
    def setup
      super
      @app = lambda { |env| [200, { "Content-Type" => "text/html" }, ["<html><body>Test</body></html>"]] }
      @middleware = Middleware.new @app
      @env = {
        "HTTP_ACCEPT" => "text/html",
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/test",
        "HTTP_HOST" => "example.com"
      }
    end

    def test_file_storage_integration
      with_storage_config storage: Storage::FileAdapter do
        uuid = "test-file-uuid_vernier"
        profile_key = "#{uuid}:profile"

        Storage.store profile_key, '{"test": "profile"}'

        assert_equal '{"test": "profile"}', Storage.fetch(profile_key)
      end
    end

    def test_redis_storage_integration
      mock_redis = MockRedisClient.new
      with_storage_config storage: Storage::RedisAdapter, storage_options: { client: mock_redis } do
        uuid = "test-redis-uuid_vernier"
        profile_key = "#{uuid}:profile"

        Storage.store profile_key, '{"test": "profile"}'

        assert mock_redis.stored_data.any?, "Expected data to be stored in Redis"
        assert_equal 1, mock_redis.stored_data.keys.count { |k| k.include? ":profile" }
      end
    end

    def test_memcached_storage_integration
      mock_memcached = MockMemcachedClient.new
      with_storage_config storage: Storage::MemcachedAdapter, storage_options: { client: mock_memcached } do
        uuid = "test-memcached-uuid_vernier"
        profile_key = "#{uuid}:profile"

        Storage.store profile_key, '{"test": "profile"}'

        assert mock_memcached.stored_data.any?, "Expected data to be stored in Memcached"
        assert_equal 1, mock_memcached.stored_data.keys.count { |k| k.include? ":profile" }
      end
    end

    def test_redis_propagates_connection_errors
      failing_redis = FailingRedisClient.new
      with_storage_config storage: Storage::RedisAdapter, storage_options: { client: failing_redis } do
        error = assert_raises StandardError do
          Storage.store "test_key_vernier:profile", "test_data"
        end
        assert_equal "Redis connection failed", error.message

        error = assert_raises StandardError do
          Storage.fetch "test_key_vernier:profile"
        end
        assert_equal "Redis connection failed", error.message
      end
    end

    private

    def with_storage_config options = {}
      original_config = Dial._configuration.instance_variable_get :@options
      new_config = original_config.merge(options).merge(sampling_percentage: 100)

      Dial._configuration.instance_variable_set :@options, new_config
      Storage.instance_variable_set :@adapter, nil
      yield
    ensure
      Dial._configuration.instance_variable_set :@options, original_config
      Storage.instance_variable_set :@adapter, nil
    end

    class MockRedisClient
      attr_reader :stored_data

      def initialize
        @stored_data = {}
      end

      def setex key, ttl, value
        @stored_data[key] = value
        "OK"
      end

      def get key
        @stored_data[key]
      end

      def del key
        @stored_data.delete key
      end
    end

    class MockMemcachedClient
      attr_reader :stored_data

      def initialize
        @stored_data = {}
      end

      def set key, value, ttl
        @stored_data[key] = value
        true
      end

      def get key
        @stored_data[key]
      end

      def delete key
        @stored_data.delete key
        true
      end
    end

    class FailingRedisClient
      def setex key, ttl, value
        raise "Redis connection failed"
      end

      def get key
        raise "Redis connection failed"
      end

      def del key
        raise "Redis connection failed"
      end
    end
  end
end
