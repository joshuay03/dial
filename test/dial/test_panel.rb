# frozen_string_literal: true

require "test_helper"

module Dial
  class TestPanel < Dial::Test
    def setup
      unless app.initialized?
        app.initialize!

        ActiveRecord::Schema.define do
          create_table :gauges, force: true do
          end

          create_table :indicators, force: true do |t|
            t.belongs_to :gauge, null: false
          end
        end

        10.times do
          gauge = Gauge.create!
          Indicator.create! gauge: gauge
        end

        app.routes.draw do
          mount Dial::Engine, at: "/"
          root "dials#dial"
        end
      end

      get "/", nil, { "HTTP_ACCEPT" => "text/html" }

      assert last_response.ok?
    end

    def test_controller
      assert_select "#dial-preview-header", text: /Controller: dials/
    end

    def test_action
      assert_select "#dial-preview-header", text: /Action: dial/
    end

    def test_rails_version
      assert_select "#dial-preview-rails-version", text: /Rails version: #{Rails::VERSION::STRING}/
    end

    def test_rack_version
      assert_select "#dial-preview-rack-version", text: /Rack version: #{Rack.release}/
    end

    def test_ruby_version
      assert_select "#dial-preview-ruby-version", text: /Ruby version: #{Regexp.escape RUBY_DESCRIPTION}/
    end

    def test_request_timing
      assert_select "#dial-preview-header", text: /Request timing: \d+\.\d{1,2}ms/
    end

    def test_view_profile
      assert_select "#dial-preview-header" do
        assert_select "a[target=_blank]", text: "View profile" do |link|
          assert_match (/^https:\/\/vernier\.prof\/from-url\/.*_vernier$/), link.first["href"]
        end
      end
    end

    def test_n_plus_ones
      assert_select "#dial-details-n-plus-ones" do
        assert_select "summary", text: "N+1s"
        assert_select "summary", text: <<-SQL.squish
          SELECT "indicators".* FROM "indicators" WHERE "indicators"."gauge_id" = ? /* Long annotation so the ...
        SQL
        assert_select "span", text: <<-SQL.squish, count: 4
          SELECT "indicators".* FROM "indicators" WHERE "indicators"."gauge_id" = ? /* Long annotation so the query exceeds the maximum length for presentation */ LIMIT ?
        SQL
        assert_select "span", text: "+ 5 more queries"
      end
    end

    def test_server_timing
      assert_select "#dial-details-server-timing" do
        assert_select "summary", text: "Server timing"
        assert_select "span", text: /process_action.action_controller: \d+\.\d{1,2}/
      end
    end

    def test_ruby_vm_stat
      assert_select "#dial-details-ruby-vm-stat" do
        assert_select "summary", text: "RubyVM stat"
        assert_select "span", text: /constant_cache_invalidations: \d+/
      end
    end

    def test_gc_stat
      assert_select "#dial-details-gc-stat" do
        assert_select "summary", text: "GC stat"
        assert_select "span", text: /count: \d+/
      end
    end

    def test_gc_stat_heap
      assert_select "#dial-details-gc-stat-heap" do
        assert_select "summary", text: "GC stat heap"
        assert_select "span", text: "Heap slot 0"
        assert_select "span", text: /slot_size: \d+/
      end
    end
  end
end
