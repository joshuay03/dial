# frozen_string_literal: true

require "test_helper"

module Dial
  class TestProsopiteCompositeLogger < ActiveSupport::TestCase
    def setup
      @dial_logger = ProsopiteLogger.new
      @existing_logger = Logger.new StringIO.new
      @composite_logger = ProsopiteCompositeLogger.new @dial_logger, @existing_logger
    end

    def test_composite_logger_delegates_to_both_loggers
      message = "Test N+1 query detected"

      @composite_logger.warn message

      assert_includes ProsopiteLogger.log_io.string, message
      assert @existing_logger.respond_to? :warn
    end

    def test_composite_logger_handles_nil_existing_logger
      composite_logger = ProsopiteCompositeLogger.new @dial_logger, nil

      assert_nothing_raised do
        composite_logger.warn "Test message"
      end

      assert_includes ProsopiteLogger.log_io.string, "Test message"
    end

    def test_composite_logger_forwards_all_methods
      assert_nothing_raised do
        @composite_logger.info "test info"
        @composite_logger.add Logger::WARN, "test add"
      end

      log_content = ProsopiteLogger.log_io.string
      assert_includes log_content, "test info"
      assert_includes log_content, "test add"
    end

    def test_composite_logger_level_getter_and_setter
      @dial_logger.level = Logger::ERROR
      assert_equal Logger::ERROR, @composite_logger.level

      @composite_logger.level = Logger::WARN
      assert_equal Logger::WARN, @dial_logger.level
      assert_equal Logger::WARN, @existing_logger.level
    end

    def test_method_missing_delegation
      assert @composite_logger.respond_to? :progname

      assert_nothing_raised do
        @composite_logger.progname
      end
    end

    def test_respond_to_missing_works_correctly
      assert @composite_logger.respond_to? :warn
      assert @composite_logger.respond_to? :progname
      refute @composite_logger.respond_to? :nonexistent_method
    end
  end
end
