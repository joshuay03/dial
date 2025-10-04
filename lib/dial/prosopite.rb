# frozen_string_literal: true

require "active_support/core_ext/string/filters"

require_relative "prosopite_composite_logger"

module Dial
  module Prosopite
    def custom_logger= logger
      return super logger if @setting_dial_logger

      @original_logger = logger

      if @dial_logger && @original_logger
        super ProsopiteCompositeLogger.new @dial_logger, @original_logger
      else
        super logger
      end
    end

    def dial_logger= logger
      @dial_logger = logger

      @setting_dial_logger = true
      if @original_logger
        self.custom_logger = ProsopiteCompositeLogger.new @dial_logger, @original_logger
      else
        self.custom_logger = @dial_logger
      end
    ensure
      @setting_dial_logger = false
    end

    def send_notifications
      tc[:prosopite_notifications] = tc[:prosopite_notifications].to_h do |queries, kaller|
        [queries.map { |query| query.squish }, kaller]
      end

      super
    end
  end
end

module ::Prosopite
  class << self
    prepend Dial::Prosopite
  end
end
