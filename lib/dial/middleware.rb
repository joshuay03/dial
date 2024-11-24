# frozen_string_literal: true

require "securerandom"

require "vernier"
require "prosopite"

require_relative "middleware/panel"
require_relative "middleware/ruby_stat"
require_relative "middleware/rails_stat"

module Dial
  class Middleware
    include RubyStat
    include RailsStat

    def initialize app
      @app = app
    end

    def call env
      start_time = Process.clock_gettime Process::CLOCK_MONOTONIC

      profile_out_filename = "#{SecureRandom.uuid_v7}.json"
      profile_out_pathname = "#{profile_out_dir_pathname}#{profile_out_filename}"

      status, headers, rack_body = nil
      ruby_vm_stat, gc_stat, gc_stat_heap = nil
      ::Prosopite.scan do
        ::Vernier.profile out: profile_out_pathname, interval: 500, allocation_interval: 1000 do
          ruby_vm_stat, gc_stat, gc_stat_heap = with_diffed_ruby_stats do
            status, headers, rack_body = @app.call env
          end
        end
      end
      server_timing = server_timing headers

      unless headers[::Rack::CONTENT_TYPE]&.include? "text/html"
        File.delete profile_out_pathname if File.exist? profile_out_pathname
        return [status, headers, rack_body]
      end

      query_logs = clear_query_logs!
      remove_stale_profile_out_files!

      finish_time = Process.clock_gettime Process::CLOCK_MONOTONIC
      env[REQUEST_TIMING_HEADER] = ((finish_time - start_time) * 1_000).round 2

      body = String.new.tap do |str|
        rack_body.each { |chunk| str << chunk }
        rack_body.close if rack_body.respond_to? :close
      end.sub "</body>", <<~HTML
          #{Panel.html env, profile_out_filename, query_logs, ruby_vm_stat, gc_stat, gc_stat_heap, server_timing}
        </body>
      HTML

      headers[::Rack::CONTENT_LENGTH] = body.bytesize.to_s

      [status, headers, [body]]
    end

    private

    def with_diffed_ruby_stats
      ruby_vm_stat_before = RubyVM.stat
      gc_stat_before = GC.stat
      gc_stat_heap_before = GC.stat_heap
      yield
      [
        ruby_vm_stat_diff(ruby_vm_stat_before, RubyVM.stat),
        gc_stat_diff(gc_stat_before, GC.stat),
        gc_stat_heap_diff(gc_stat_heap_before, GC.stat_heap)
      ]
    end

    def remove_stale_profile_out_files!
      stale_profile_out_files.each do |profile_out_file|
        File.delete profile_out_file
      end
    end

    def stale_profile_out_files
      Dir.glob("#{profile_out_dir_pathname}/*.json").select do |profile_out_file|
        timestamp = Util.uuid_v7_timestamp File.basename profile_out_file
        timestamp < Time.now - PROFILE_OUT_STALE_SECONDS
      end
    end

    def profile_out_dir_pathname
      @_profile_out_dir_pathname ||= ::Rails.root.join PROFILE_OUT_RELATIVE_DIRNAME
    end

    def clear_query_logs!
      [].tap do |query_logs|
        File.open(query_log_pathname, "r+") do |file|
          entry = reading_section = query_count = nil
          file.each_line do |line|
            case line
            when /N\+1 queries detected/
              entry = [[], []]
              reading_section = :queries
              query_count = 0
            when /Call stack/
              reading_section = :call_stack
              if query_count > 5
                entry.first << "+ #{query_count - 5} more queries"
              end
            else
              case reading_section
              when :queries
                query_count += 1
                entry.first << line.strip if query_count <= 5
              when :call_stack
                if line.strip.empty?
                  query_logs << entry
                  reading_section = nil
                else
                  entry.last << line.strip
                end
              end
            end
          end

          file.truncate 0
          file.rewind
        end
      end
    end

    def query_log_pathname
      @_query_log_dir_pathname ||= ::Rails.root.join PROSOPITE_LOG_RELATIVE_PATHNAME
    end
  end
end
