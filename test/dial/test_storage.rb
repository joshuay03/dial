# frozen_string_literal: true

require_relative "../test_helper"

module Dial
  class TestStorage < Dial::Test
    def setup
      super
      reset_storage_adapter
    end

    def teardown
      super
      reset_storage_adapter
    end

    def test_adapter_defaults_to_file_in_development
      with_rails_env "development" do
        with_storage_config storage: Storage::FileAdapter do
          adapter = Storage.adapter
          assert_instance_of Storage::FileAdapter, adapter
        end
      end
    end

    def test_adapter_defaults_to_file_in_production
      with_rails_env "production" do
        with_storage_config storage: Storage::FileAdapter do
          adapter = Storage.adapter
          assert_instance_of Storage::FileAdapter, adapter
        end
      end
    end

    def test_adapter_builds_redis_adapter
      mock_client = Minitest::Mock.new
      with_storage_config storage: Storage::RedisAdapter, storage_options: { client: mock_client } do
        adapter = Storage.adapter
        assert_instance_of Storage::RedisAdapter, adapter
      end
    end

    def test_adapter_builds_memcached_adapter
      mock_client = Minitest::Mock.new
      with_storage_config storage: Storage::MemcachedAdapter, storage_options: { client: mock_client } do
        adapter = Storage.adapter
        assert_instance_of Storage::MemcachedAdapter, adapter
      end
    end

    def test_adapter_raises_error_on_invalid_storage_type
      with_storage_config storage: "invalid" do
        error = assert_raises ArgumentError do
          Storage.adapter
        end
        assert_match(/Unsupported storage type: invalid/, error.message)
        assert_match(/Supported adapters:/, error.message)
      end
    end

    def test_adapter_raises_error_on_redis_initialization_error
      with_storage_config storage: Storage::RedisAdapter, storage_options: { ttl: 3600 } do
        error = assert_raises ArgumentError do
          Storage.adapter
        end
        assert_match(/Redis client required/, error.message)
      end
    end

    def test_store_delegates_to_adapter
      mock_adapter = Object.new
      def mock_adapter.store(key, data, ttl: nil)
        @called = true
        @key = key
        @data = data
        @ttl = ttl
      end

      def mock_adapter.called?; @called; end
      def mock_adapter.stored_key; @key; end
      def mock_adapter.stored_data; @data; end
      def mock_adapter.stored_ttl; @ttl; end

      Storage.instance_variable_set :@adapter, mock_adapter
      Storage.store "key", "data"

      assert mock_adapter.called?
      assert_equal "key", mock_adapter.stored_key
      assert_equal "data", mock_adapter.stored_data
      assert_nil mock_adapter.stored_ttl
    end

    def test_fetch_delegates_to_adapter
      mock_adapter = Minitest::Mock.new
      mock_adapter.expect :fetch, "result", ["key"]

      Storage.instance_variable_set :@adapter, mock_adapter
      result = Storage.fetch "key"
      assert_equal "result", result
      mock_adapter.verify
    end

    def test_delete_delegates_to_adapter
      mock_adapter = Minitest::Mock.new
      mock_adapter.expect :delete, nil, ["key"]

      Storage.instance_variable_set :@adapter, mock_adapter
      Storage.delete "key"
      mock_adapter.verify
    end

    def test_cleanup_delegates_to_adapter_when_supported
      mock_adapter = Minitest::Mock.new
      mock_adapter.expect :cleanup, nil, []
      def mock_adapter.respond_to? method
        method == :cleanup
      end

      Storage.instance_variable_set :@adapter, mock_adapter
      Storage.cleanup
      mock_adapter.verify
    end

    def test_cleanup_does_nothing_when_adapter_doesnt_support_it
      mock_adapter = Minitest::Mock.new
      def mock_adapter.respond_to? method
        false
      end

      Storage.instance_variable_set :@adapter, mock_adapter
      Storage.cleanup # Should not raise
    end

    private

    def reset_storage_adapter
      Storage.instance_variable_get(:@mutex).synchronize do
        Storage.instance_variable_set :@adapter, nil
      end
    end

    def with_storage_config options = {}
      original_config = Dial._configuration.instance_variable_get :@options
      new_config = original_config.merge options

      Dial._configuration.instance_variable_set :@options, new_config
      yield
    ensure
      Dial._configuration.instance_variable_set :@options, original_config
    end

    def with_rails_env env
      original_env = Rails.env
      Rails.env = env
      yield
    ensure
      Rails.env = original_env
    end
  end
end
