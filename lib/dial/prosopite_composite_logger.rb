# frozen_string_literal: true

require "logger"

module Dial
  class ProsopiteCompositeLogger
    def initialize dial_logger, existing_logger = nil
      @dial_logger = dial_logger
      @existing_logger = existing_logger
    end

    def level
      @dial_logger.level
    end

    def level= value
      @dial_logger.level = value
      @existing_logger.level = value if @existing_logger&.respond_to? :level=
    end

    def method_missing method, *args, &block
      result = nil
      result = @dial_logger.send method, *args, &block if @dial_logger.respond_to? method
      @existing_logger.send method, *args, &block if @existing_logger&.respond_to? method
      result
    end

    def respond_to_missing? method, include_private = false
      @dial_logger.respond_to?(method, include_private) ||
        @existing_logger&.respond_to?(method, include_private) ||
          false
    end
  end
end
