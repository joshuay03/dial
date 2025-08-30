# frozen_string_literal: true

require "test_helper"

module Dial
  class TestConfiguration < Dial::Test
    def test_configure_yields_a_new_configuration
      Dial.configure do |config|
        assert_instance_of Dial::Configuration, config
      end
    end

    def test_configuration_has_default_values
      Dial.configure do |config|
        assert_equal 100, config.sampling_percentage
        assert_instance_of Proc, config.content_security_policy_nonce
        assert_equal VERNIER_INTERVAL, config.vernier_interval
        assert_equal VERNIER_ALLOCATION_INTERVAL, config.vernier_allocation_interval
        assert_equal PROSOPITE_IGNORE_QUERIES, config.prosopite_ignore_queries
        assert_equal (nonce = SecureRandom.base64(16)), config.content_security_policy_nonce.call({ NONCE => nonce }, {})
        assert_equal "", config.content_security_policy_nonce.call({}, {})
      end
    end

    def test_configuration_can_be_changed
      Dial.configure do |config|
        config.sampling_percentage = 25
        config.content_security_policy_nonce = lambda { |_env, headers| headers["TEST_NONCE"] }
        config.vernier_interval = 50
        config.vernier_allocation_interval = 100
        config.prosopite_ignore_queries = [/only_ignore_me/]

        assert_equal 25, config.sampling_percentage
        assert_equal 50, config.vernier_interval
        assert_equal 100, config.vernier_allocation_interval
        assert_equal [/only_ignore_me/], config.prosopite_ignore_queries
        assert_equal "test_nonce", config.content_security_policy_nonce.call({}, { "TEST_NONCE" => "test_nonce" })
      end
    end
  end

  class TestConfigurationIntegration < Dial::Test
    def teardown
      super

      FileUtils.rm_rf app.root.join "config"
    end

    def test_configuration_can_be_changed
      config_initializer <<~RUBY
        Dial.configure do |config|
          config.sampling_percentage = 25
          config.vernier_interval = 50
          config.vernier_allocation_interval = 100
          config.prosopite_ignore_queries = [/only_ignore_me/]
        end
      RUBY
      app(true).initialize!

      assert_equal 25, Dial._configuration.sampling_percentage
      assert_equal 50, Dial._configuration.vernier_interval
      assert_equal 100, Dial._configuration.vernier_allocation_interval
      assert_equal [/only_ignore_me/], Dial._configuration.prosopite_ignore_queries
    end

    def test_configuration_is_frozen_after_app_initialization
      app(true).initialize!
      error = assert_raises RuntimeError do
        Dial.configure do |config|
          config.sampling_percentage = 50
        end
      end
      assert_match (/can\'t modify frozen Hash:.*sampling_percentage/), error.message
    end

    private

    def config_initializer content, name: "dial_initializer"
      config_dir = app.root.join "config"
      Dir.mkdir config_dir unless Dir.exist? config_dir
      initializers_dir = app.root.join "config/initializers"
      Dir.mkdir initializers_dir unless Dir.exist? initializers_dir
      intializer_file = app.root.join "config/initializers/#{name}.rb"
      File.write intializer_file, content
    end
  end
end
