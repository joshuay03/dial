# frozen_string_literal: true

require "rack"

require_relative "version"

module Dial
  PROGRAM_ID = Process.getsid Process.pid

  HTTP_ACCEPT = "HTTP_ACCEPT"
  CONTENT_TYPE = ::Rack::CONTENT_TYPE
  CONTENT_LENGTH = ::Rack::CONTENT_LENGTH
  REQUEST_TIMING = "dial_request_timing"

  FILE_STALE_SECONDS = 60 * 60

  VERNIER_INTERVAL = 200
  VERNIER_ALLOCATION_INTERVAL = 20_000
  VERNIER_PROFILE_OUT_RELATIVE_DIRNAME = "tmp/dial/profiles"

  PROSOPITE_IGNORE_QUERIES = [/schema_migrations/i].freeze
  PROSOPITE_LOG_RELATIVE_DIRNAME = "log/dial"
  PROSOPITE_LOG_FILENAME = "#{Util.uuid}_prosopite_#{PROGRAM_ID}.log".freeze
end
