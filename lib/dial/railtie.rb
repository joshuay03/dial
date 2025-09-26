# frozen_string_literal: true

require "rails"
require "active_record"
require "prosopite"

require_relative "middleware"
require_relative "prosopite_logger"

module Dial
  class Railtie < ::Rails::Railtie
    initializer "dial.setup", after: :load_config_initializers do |app|
      app.config.after_initialize do
        # set up prosopite
        if ::ActiveRecord::Base.configurations.configurations.any? { |config| config.adapter == "postgresql" }
          require "pg_query"
        end
        ::Prosopite.custom_logger = ProsopiteLogger.new

        # finalize configuration
        Dial._configuration.freeze
        ::Prosopite.ignore_queries = Dial._configuration.prosopite_ignore_queries
      end
    end

    initializer "dial.middleware", before: :build_middleware_stack do |app|
      # use middleware
      app.middleware.insert_before 0, Middleware
    end
  end
end
