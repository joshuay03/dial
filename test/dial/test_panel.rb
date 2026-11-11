# frozen_string_literal: true

require "test_helper"

module Dial
  class TestPanel < Dial::Test
    def setup
      unless app.initialized?
        app.initialize!

        ActiveRecord::Migration.verbose = false
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

      @existing_threads = Thread.list
      get "/", nil, { "HTTP_ACCEPT" => "text/html" }

      assert last_response.ok?
    end

    def teardown
      (Thread.list - @existing_threads).each(&:join)

      super
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
        assert_select "span", text: <<-SQL.squish
          SELECT "indicators".* FROM "indicators" WHERE "indicators"."gauge_id" = ? /* Long annotation so the query exceeds the maximum length for presentation and contains newlines */ LIMIT ?
        SQL
        assert_select "span", text: "+ 9 more queries"
      end
    end

    def test_n_plus_ones_with_possible_fix_and_context
      ProsopiteLogger.log_io.write <<~LOG
        N+1 queries detected (2 queries, 1.0ms):
          SELECT widgets WHERE id = 1
          SELECT widgets WHERE id = 2
        Possible fix:
          Widget.includes(:owner)
        Context:
          Loading widgets

          for the dashboard
        Call stack:
          app/example.rb:1

      LOG

      get "/", nil, { "HTTP_ACCEPT" => "text/html" }

      assert last_response.ok?
      assert_select "#dial-details-n-plus-ones details", text: /SELECT widgets/ do
        assert_select "summary", text: "SELECT widgets WHERE id = 1"
        assert_select "span", text: "+ 1 more queries"
        assert_select "span", text: "Possible fix:"
        assert_select "span", text: "Widget.includes(:owner)"
        assert_select "span", text: "Context:"
        assert_select "span", text: "Loading widgets"
        assert_select "span", text: "for the dashboard"
        assert_select "span", text: "app/example.rb:1"
      end
    end

    def test_n_plus_ones_with_possible_fixes
      ProsopiteLogger.log_io.write <<~LOG
        N+1 queries detected (2 queries, 1.0ms):
          SELECT widgets WHERE id = 1
          SELECT widgets WHERE id = 2
        Possible fixes:
          Widget.includes(:owner)
          Widget.preload(:owner)
        Call stack:
          app/example.rb:1

      LOG

      get "/", nil, { "HTTP_ACCEPT" => "text/html" }

      assert last_response.ok?
      assert_select "#dial-details-n-plus-ones details", text: /SELECT widgets/ do
        assert_select "summary", text: "SELECT widgets WHERE id = 1"
        assert_select "span", text: "+ 1 more queries"
        assert_select "span", text: "Possible fixes:"
        assert_select "span", text: "Widget.includes(:owner)"
        assert_select "span", text: "Widget.preload(:owner)"
        assert_select "span", text: "app/example.rb:1"
      end
    end

    def test_n_plus_ones_with_context
      ProsopiteLogger.log_io.write <<~LOG
        N+1 queries detected (2 queries, 1.0ms):
          SELECT widgets WHERE id = 1
          SELECT widgets WHERE id = 2
        Context:
          Loading widgets
          for the dashboard
        Call stack:
          app/example.rb:1

      LOG

      get "/", nil, { "HTTP_ACCEPT" => "text/html" }

      assert last_response.ok?
      assert_select "#dial-details-n-plus-ones details", text: /SELECT widgets/ do
        assert_select "summary", text: "SELECT widgets WHERE id = 1"
        assert_select "span", text: "+ 1 more queries"
        assert_select "span", text: "Context:"
        assert_select "span", text: "Loading widgets"
        assert_select "span", text: "for the dashboard"
        assert_select "span", text: "app/example.rb:1"
      end
    end

    def test_n_plus_ones_with_html
      ProsopiteLogger.log_io.write <<~LOG
        N+1 queries detected (2 queries, 1.0ms):
          SELECT widgets WHERE name = '<widget>' AND owner = 'A&B'
          SELECT widgets WHERE name = '<other>' AND owner = 'A&B'
        Possible fix:
          Widget.where("name < ?", "<widget>").includes(:owner)
        Context:
          Loading <widgets> & owners
          <img src=x onerror=alert(1)>
        Call stack:
          app/<widgets>&owners.rb:1

      LOG

      get "/", nil, { "HTTP_ACCEPT" => "text/html" }

      assert last_response.ok?
      assert_select "#dial-details-n-plus-ones details", text: /SELECT widgets/ do
        assert_select "summary", text: "SELECT widgets WHERE name = '<widget>' AND owner = 'A&B'"
        assert_select "span", text: "SELECT widgets WHERE name = '<widget>' AND owner = 'A&B'"
        assert_select "span", text: "+ 1 more queries"
        assert_select "span", text: 'Widget.where("name < ?", "<widget>").includes(:owner)'
        assert_select "span", text: "Loading <widgets> & owners"
        assert_select "span", text: "<img src=x onerror=alert(1)>"
        assert_select "span", text: "app/<widgets>&owners.rb:1"
        assert_select "img, widget, widgets", false
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

    def test_hidden_indicator
      assert_select "#dial-hidden-indicator", text: "Dial"
    end

    def test_toggle_shortcut_keys_script
      assert_select "script", text: /var keys = \["Alt","Shift","D"\];/
    end
  end
end
