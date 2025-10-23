# frozen_string_literal: true

require "rack"
require "action_dispatch"
require "stringio"

require_relative "version"

module Dial
  PROGRAM_ID = Process.getsid Process.pid

  HTTP_ACCEPT = "HTTP_ACCEPT"
  CONTENT_TYPE = ::Rack::CONTENT_TYPE
  CONTENT_TYPE_HTML = "text/html"
  CONTENT_LENGTH = ::Rack::CONTENT_LENGTH
  NONCE = ::ActionDispatch::ContentSecurityPolicy::Request::NONCE
  REQUEST_TIMING = "dial_request_timing"

  FORCE_PARAM = "dial_force"
  SAMPLING_PERCENTAGE_DEV = 100
  SAMPLING_PERCENTAGE_PROD = 1
  STORAGE_TTL = 60 * 60
  EMPTY_NONCE = ""
  TOGGLE_SHORTCUT_KEYS = ["Alt", "Shift", "D"].freeze

  VERNIER_INTERVAL = 200
  VERNIER_ALLOCATION_INTERVAL = 2_000
  VERNIER_PROFILE_OUT_RELATIVE_DIRNAME = "tmp/dial/profiles"
  VERNIER_PROFILE_OUT_FILE_EXTENSION = ".json.gz"
  VERNIER_VIEWER_URL = "https://vernier.prof"

  PROSOPITE_IGNORE_QUERIES = [/schema_migrations/i].freeze
end
