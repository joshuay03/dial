# frozen_string_literal: true

require "test_helper"

class TestDial < Dial::Test
  def test_that_it_has_a_version_number
    refute_nil ::Dial::VERSION
  end
end
