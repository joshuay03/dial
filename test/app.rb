# frozen_string_literal: true

require "rack/test"

require "active_record/railtie"
require "action_controller/railtie"

ENV["DATABASE_URL"] = "sqlite3::memory:"

class DialApp < Rails::Application
  config.eager_load = false
  config.logger = Logger.new nil
  config.secret_key_base = "secret_key_base"
  config.hosts << "example.org"
  config.server_timing = true

  config.active_support.deprecation = :silence
  def initialize!
    verbose = $VERBOSE
    $VERBOSE = nil

    super
  ensure
    $VERBOSE = verbose
  end
end

class Gauge < ActiveRecord::Base
  has_one :indicator
end

class Indicator < ActiveRecord::Base
  belongs_to :gauge

  default_scope { annotate <<~ANNOTATION }
    Long annotation so the query exceeds the maximum length for presentation
    and contains newlines
  ANNOTATION
end

class DialsController < ActionController::Base
  def dial
    Gauge.all.each do |gauge|
      gauge.reload.indicator # N+1
    end

    render plain: <<-HTML, content_type: "text/html"
      <html>
        <head>
          <title>Dial</title>
        </head>
        <body>
          <h1>Dial</h1>
        </body>
      </html>
    HTML
  end
end

def app new = false
  if new
    DialApp.new
  else
    Rails.application
  end
end
