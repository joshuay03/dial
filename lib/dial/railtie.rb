# frozen_string_literal: true

require "rails"
require "active_record"
require "prosopite"

require_relative "middleware"
require_relative "prosopite_logger"

module Dial
  class Railtie < ::Rails::Railtie
    initializer "dial.setup", after: :load_config_initializers do |app|
      # use middleware
      app.middleware.insert_before 0, Middleware

      # clean up stale vernier profile output files
      stale_files("#{profile_out_dir_pathname}/*" + VERNIER_PROFILE_OUT_FILE_EXTENSION).each do |profile_out_file|
        File.delete profile_out_file rescue nil
      end

      app.config.after_initialize do
        # set up vernier
        FileUtils.mkdir_p ::Rails.root.join VERNIER_PROFILE_OUT_RELATIVE_DIRNAME

        # set up prosopite
        if ::ActiveRecord::Base.configurations.configurations.any? { |config| config.adapter == "postgresql" }
          require "pg_query"
        end
        ::Prosopite.custom_logger = ProsopiteLogger.new PROSOPITE_LOG_IO

        # finalize configuration
        Dial._configuration.freeze
        ::Prosopite.ignore_queries = Dial._configuration.prosopite_ignore_queries
      end
    end

    private

    def stale_files glob_pattern
      Dir.glob(glob_pattern).select do |file|
        timestamp = Util.uuid_timestamp Util.file_name_uuid File.basename file
        timestamp < Time.now - FILE_STALE_SECONDS
      end
    end

    def profile_out_dir_pathname
      ::Rails.root.join VERNIER_PROFILE_OUT_RELATIVE_DIRNAME
    end
  end
end
