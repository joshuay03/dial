# frozen_string_literal: true

require "rails"
require "prosopite"

require_relative "middleware"
require_relative "prosopite_logger"

module Dial
  class Railtie < ::Rails::Railtie
    initializer "dial.use_middleware" do |app|
      app.middleware.insert_before 0, Middleware
    end

    initializer "dial.set_up_vernier" do |app|
      app.config.after_initialize do
        FileUtils.mkdir_p ::Rails.root.join PROFILE_OUT_RELATIVE_DIRNAME
      end
    end

    initializer "dial.set_up_prosopite" do |app|
      app.config.after_initialize do
        if ::ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
          require "pg_query"
        end

        prosopite_log_pathname = ::Rails.root.join PROSOPITE_LOG_RELATIVE_PATHNAME
        FileUtils.mkdir_p File.dirname prosopite_log_pathname
        File.open(prosopite_log_pathname, "w") {}
        ::Prosopite.custom_logger = ProsopiteLogger.new prosopite_log_pathname

        ::Prosopite.ignore_queries = PROSOPITE_IGNORE_QUERIES
      end
    end
  end
end
