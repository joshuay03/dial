# frozen_string_literal: true

require_relative "version"

module Dial
  REQUEST_TIMING_HEADER = "dial_request_timing"

  PROFILE_OUT_STALE_SECONDS = 60 * 60
  PROFILE_OUT_RELATIVE_DIRNAME = "tmp/dial/profile/"

  PROSOPITE_IGNORE_QUERIES = [/schema_migrations/]
  PROSOPITE_LOG_RELATIVE_PATHNAME = "log/dial/prosopite.log"
end
