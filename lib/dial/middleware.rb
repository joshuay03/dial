# frozen_string_literal: true

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
      unless env[HTTP_ACCEPT]&.include? "text/html"
        return @app.call env
      end

      start_time = Process.clock_gettime Process::CLOCK_MONOTONIC

      profile_out_filename = "#{Util.uuid}_vernier.json.gz"
      profile_out_pathname = "#{profile_out_dir_pathname}/#{profile_out_filename}"

      status, headers, rack_body, ruby_vm_stat, gc_stat, gc_stat_heap, vernier_result = nil
      ::Prosopite.scan do
        vernier_result = ::Vernier.profile interval: Dial._configuration.vernier_interval, \
                                           allocation_interval: Dial._configuration.vernier_allocation_interval, \
                                           hooks: [:memory_usage, :rails] do
          ruby_vm_stat, gc_stat, gc_stat_heap = with_diffed_ruby_stats do
            status, headers, rack_body = @app.call env
          end
        end
      end
      server_timing = server_timing headers

      unless headers[CONTENT_TYPE]&.include? "text/html"
        return [status, headers, rack_body]
      end

      write_vernier_result! vernier_result, profile_out_pathname
      query_logs = clear_query_logs!

      finish_time = Process.clock_gettime Process::CLOCK_MONOTONIC
      env[REQUEST_TIMING] = ((finish_time - start_time) * 1_000).round 2

      body = String.new.tap do |str|
        rack_body.each { |chunk| str << chunk }
        rack_body.close if rack_body.respond_to? :close

        str.sub! "</body>", <<~HTML
            #{Panel.html env, headers, profile_out_filename, query_logs, ruby_vm_stat, gc_stat, gc_stat_heap, server_timing}
          </body>
        HTML
      end

      headers[CONTENT_LENGTH] = body.bytesize.to_s

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

    def write_vernier_result! result, pathname
      Thread.new do
        Thread.current.name = "Dial::Middleware#write_vernier_result!"
        Thread.current.report_on_exception = false

        result.write out: pathname
      end
    end

    def clear_query_logs!
      [].tap do |query_logs|
        File.open "#{query_log_dir_pathname}/#{PROSOPITE_LOG_FILENAME}", "r+" do |file|
          entry = section = count = nil
          file.each_line do |line|
            entry, section, count = process_query_log_line line, entry, section, count
            query_logs << entry if entry && section.nil?
          end

          file.truncate 0
          file.rewind
        end
      end
    end

    def process_query_log_line line, entry, section, count
      case line
      when /N\+1 queries detected/
        [[[],[]], :queries, 0]
      when /Call stack/
        entry.first << "+ #{count - 5} more queries" if count > 5
        [entry, :call_stack, count]
      else
        case section
        when :queries
          count += 1
          entry.first << line.strip if count <= 5
          [entry, :queries, count]
        when :call_stack
          if line.strip.empty?
            [entry, nil, count]
          else
            entry.last << line.strip
            [entry, section, count]
          end
        end
      end
    end

    def profile_out_dir_pathname
      ::Rails.root.join VERNIER_PROFILE_OUT_RELATIVE_DIRNAME
    end

    def query_log_dir_pathname
      ::Rails.root.join PROSOPITE_LOG_RELATIVE_DIRNAME
    end
  end
end
