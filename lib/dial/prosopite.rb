# frozen_string_literal: true

module Dial
  module Prosopite
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
