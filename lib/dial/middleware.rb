# frozen_string_literal: true

require "vernier"
require "prosopite"

require_relative "prosopite"
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
      unless env[HTTP_ACCEPT]&.include? CONTENT_TYPE_HTML
        return @app.call env
      end

      unless should_profile?
        return @app.call env
      end

      start_time = Process.clock_gettime Process::CLOCK_MONOTONIC

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

      unless headers[CONTENT_TYPE]&.include? CONTENT_TYPE_HTML
        return [status, headers, rack_body]
      end

      finish_time = Process.clock_gettime Process::CLOCK_MONOTONIC
      env[REQUEST_TIMING] = ((finish_time - start_time) * 1_000).round 2

      profile_key = Storage.generate_profile_key
      store_profile_data! vernier_result, (Storage.profile_storage_key profile_key)
      query_logs = clear_query_logs!
      server_timing = server_timing headers
      panel_html = Panel.html env, headers, profile_key, query_logs, ruby_vm_stat, gc_stat, gc_stat_heap, server_timing
      body = PanelInjector.new rack_body, panel_html

      headers.delete CONTENT_LENGTH

      [status, headers, body]
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

    def store_profile_data! vernier_result, profile_storage_key
      Thread.new(vernier_result, profile_storage_key) do |vernier_result, profile_storage_key|
        Thread.current.name = "Dial::Middleware#store_profile_data!"
        Thread.current.report_on_exception = false

        # TODO: Support StringIO in vernier's #write method to avoid temp file I/O
        Tempfile.create(["vernier_profile", ".json"]) do |temp_file|
          vernier_result.write out: temp_file.path
          profile_data = File.read(temp_file.path)
          Storage.store profile_storage_key, profile_data
        end

        Storage.cleanup
      end
    end

    def clear_query_logs!
      [].tap do |query_logs|
        entry = section = count = nil
        ProsopiteLogger.log_io.string.lines.each do |line|
          entry, section, count = process_query_log_line line, entry, section, count
          query_logs << entry if entry && section.nil?
        end

        ProsopiteLogger.log_io.truncate 0
        ProsopiteLogger.log_io.rewind
      end
    end

    def process_query_log_line line, entry, section, count
      case line
      when /N\+1 queries detected/
        [[[],[]], :queries, 0]
      when /Call stack/
        entry.first << "+ #{count - 1} more queries" if count > 1
        [entry, :call_stack, count]
      else
        case section
        when :queries
          count += 1
          entry.first << line.strip if count == 1
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

    def should_profile?
      rand(100) < Dial._configuration.sampling_percentage
    end
  end

  class PanelInjector
    def initialize original_body, panel_html
      @original_body = original_body
      @panel_html = panel_html
      @injected = false
    end

    def each
      @original_body.each do |chunk|
        if !@injected && chunk.include?("</body>")
          @injected = true
          yield chunk.sub("</body>", "#{@panel_html}\n</body>")
        else
          yield chunk
        end
      end

      yield @panel_html unless @injected
    ensure
      close
    end

    def close
      @original_body.close if @original_body.respond_to? :close
    end

    def call stream
      each { |chunk| stream.write chunk }
    ensure
      close
    end
  end
end
