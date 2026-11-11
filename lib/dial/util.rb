# frozen_string_literal: true

require "rack/utils"
require "securerandom"

module Dial
  module Util
    class << self
      def escape_html text
        ::Rack::Utils.escape_html text
      end

      def uuid
        SecureRandom.uuid_v7
      end

      def file_name_uuid file_name
        file_name.split("_").first
      end

      def uuid_timestamp uuid
        high_bits_hex = uuid.split("-").first(2).join[0, 12].to_i 16
        Time.at high_bits_hex / 1000.0
      end
    end
  end
end
