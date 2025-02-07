# frozen_string_literal: true

require_relative "version"

module Dial
  PROGRAM_ID = Process.getsid Process.pid

  REQUEST_TIMING_HEADER = "dial_request_timing"

  FILE_STALE_SECONDS = 60 * 60

  VERNIER_INTERVAL = 500
  VERNIER_ALLOCATION_INTERVAL = 100_000
  VERNIER_PROFILE_OUT_RELATIVE_DIRNAME = "tmp/dial/profiles"

  PROSOPITE_IGNORE_QUERIES = [/schema_migrations/].freeze
  PROSOPITE_LOG_RELATIVE_DIRNAME = "log/dial"
  PROSOPITE_LOG_FILENAME = "#{Util.uuid}_prosopite_#{PROGRAM_ID}.log".freeze
end
