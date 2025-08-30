# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake"

gem "minitest"

gem "debug"

case ENV["RAILS_VERSION"]
when "7.1"
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.5")
    gem "logger"
    gem "benchmark"
  end

  gem "sqlite3", "~> 1.4"
when "7.2"
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.5")
    gem "benchmark"
  end

  gem "sqlite3", "~> 1.4"
else
  gem "sqlite3", ">= 2.1"
end

gem "rails", ENV["RAILS_VERSION"]

gem "rails-dom-testing"

gem "redis", ">= 5.0"
gem "redis-clustering", ">= 5.0"
gem "dalli", ">= 3.0"
