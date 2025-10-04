# frozen_string_literal: true

require "test_helper"

module Dial
  class TestProsopiteIntegration < ActiveSupport::TestCase
    def setup
      ::Prosopite.instance_variable_set :@custom_logger, false
      ::Prosopite.instance_variable_set :@dial_logger, nil
      ::Prosopite.instance_variable_set :@original_logger, nil
    end

    def teardown
      ::Prosopite.instance_variable_set :@custom_logger, false
      ::Prosopite.instance_variable_set :@dial_logger, nil
      ::Prosopite.instance_variable_set :@original_logger, nil
    end

    def test_dial_logger_sets_custom_logger_when_none_exists
      test_logger = ProsopiteLogger.new

      ::Prosopite.dial_logger = test_logger

      assert_equal test_logger, ::Prosopite.instance_variable_get(:@custom_logger)
    end

    def test_dial_logger_preserves_existing_custom_logger
      existing_logger = Logger.new StringIO.new
      ::Prosopite.custom_logger = existing_logger

      dial_logger = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger

      assert_instance_of ProsopiteCompositeLogger, ::Prosopite.instance_variable_get(:@custom_logger)
    end

    def test_setting_custom_logger_after_dial_logger_creates_composite
      dial_logger = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger

      existing_logger = Logger.new StringIO.new
      ::Prosopite.custom_logger = existing_logger

      assert_instance_of ProsopiteCompositeLogger, ::Prosopite.instance_variable_get(:@custom_logger)
    end

    def test_setting_dial_logger_twice_updates_composite
      existing_logger = Logger.new StringIO.new
      ::Prosopite.custom_logger = existing_logger

      dial_logger1 = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger1

      first_composite = ::Prosopite.instance_variable_get(:@custom_logger)
      assert_instance_of ProsopiteCompositeLogger, first_composite

      dial_logger2 = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger2

      second_composite = ::Prosopite.instance_variable_get(:@custom_logger)
      assert_instance_of ProsopiteCompositeLogger, second_composite

      refute_same first_composite, second_composite
    end

    def test_composite_logger_receives_notifications
      existing_io = StringIO.new
      existing_logger = Logger.new existing_io
      ::Prosopite.custom_logger = existing_logger

      dial_logger = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger

      Thread.current[:prosopite_notifications] = {
        ["SELECT * FROM users"] => ["app/controllers/users_controller.rb:10"]
      }

      ::Prosopite.send :send_notifications

      assert_includes existing_io.string, "N+1 queries detected"
      assert_includes ProsopiteLogger.log_io.string, "N+1 queries detected"
    end

    def test_setting_same_logger_twice_does_not_create_nested_composite
      existing_logger = Logger.new StringIO.new
      ::Prosopite.custom_logger = existing_logger

      dial_logger = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger

      ::Prosopite.custom_logger = existing_logger

      custom_logger = ::Prosopite.instance_variable_get(:@custom_logger)
      assert_instance_of ProsopiteCompositeLogger, custom_logger

      dial_internal = custom_logger.instance_variable_get(:@dial_logger)
      existing_internal = custom_logger.instance_variable_get(:@existing_logger)

      assert_equal dial_logger, dial_internal
      assert_equal existing_logger, existing_internal
    end

    def test_setting_custom_logger_to_nil_removes_existing_logger
      existing_logger = Logger.new StringIO.new
      ::Prosopite.custom_logger = existing_logger

      dial_logger = ProsopiteLogger.new
      ::Prosopite.dial_logger = dial_logger

      ::Prosopite.custom_logger = nil

      assert_nil ::Prosopite.instance_variable_get(:@custom_logger)
    end
  end
end
