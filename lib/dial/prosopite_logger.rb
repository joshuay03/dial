# frozen_string_literal: true

require "logger"

module Dial
  class ProsopiteLogger < Logger
    def self.log_io
      Thread.current[:dial_prosopite_log_io] ||= StringIO.new
    end

    def initialize
      super StringIO.new
    end

    def add severity, message = nil, progname = nil
      return if severity < level

      progname = @progname if progname.nil?
      formatted_message = format_message format_severity(severity), Time.now, progname, message
      self.class.log_io.write formatted_message
    end
  end
end
