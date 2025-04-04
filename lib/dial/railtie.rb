# frozen_string_literal: true

require "rails"
require "active_record"
require "prosopite"

require_relative "middleware"
require_relative "prosopite_logger"

module Dial
  class Railtie < ::Rails::Railtie
    initializer "dial.use_middleware", after: :load_config_initializers do |app|
      app.middleware.insert_before 0, Middleware
    end

    initializer "dial.set_up_vernier", after: :load_config_initializers do |app|
      app.config.after_initialize do
        FileUtils.mkdir_p ::Rails.root.join VERNIER_PROFILE_OUT_RELATIVE_DIRNAME
      end
    end

    initializer "dial.clean_up_vernier_profile_out_files", after: :load_config_initializers do |app|
      stale_files("#{profile_out_dir_pathname}/*.json.gz").each do |profile_out_file|
        File.delete profile_out_file rescue nil
      end
    end

    initializer "dial.set_up_prosopite", after: :load_config_initializers do |app|
      app.config.after_initialize do
        if ::ActiveRecord::Base.configurations.configurations.any? { |config| config.adapter == "postgresql" }
          require "pg_query"
        end

        ::Prosopite.custom_logger = ProsopiteLogger.new PROSOPITE_LOG_IO
      end
    end

    initializer "dial.setup", after: :load_config_initializers do |app|
      app.config.after_initialize do
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
