# frozen_string_literal: true

module Dial
  module Util
    class << self
      def uuid_v7_timestamp uuid
        high_bits_hex = uuid.split("-").first(2).join[0, 12].to_i 16
        Time.at high_bits_hex / 1000.0
      end
    end
  end
end
