# frozen_string_literal: true

require_relative "../test_helper"

module Dial
  class TestMiddleware < Dial::Test
    def setup
      super
      @app = lambda { |env| [200, { "Content-Type" => "text/html" }, ["<html><body>Test</body></html>"]] }
      @middleware = Middleware.new @app
      @base_env = {
        "HTTP_ACCEPT" => "text/html",
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/test",
        "HTTP_HOST" => "example.com"
      }
      @base_request = ::Rack::Request.new @base_env
    end

    def test_should_profile_when_enabled
      assert @middleware.send :should_profile?, @base_request
    end

    def test_should_not_profile_when_not_within_sampling
      with_config sampling_percentage: 0 do
        refute @middleware.send :should_profile?, @base_request
      end
    end

    def test_should_not_profile_when_disabled
      with_config enabled: false do
        refute @middleware.send :should_profile?, @base_request
      end
    end

    def test_should_profile_when_disabled_and_forced
      with_config enabled: false, force_param: "profile" do
        env = @base_env.merge "QUERY_STRING" => "profile=1"
        request = ::Rack::Request.new env

        assert @middleware.send :should_profile?, request
      end
    end

    def test_should_profile_when_disabled_and_forced_and_not_within_sampling
      with_config enabled: false, force_param: "profile", sampling_percentage: 0 do
        env = @base_env.merge "QUERY_STRING" => "profile=1"
        request = ::Rack::Request.new env

        assert @middleware.send :should_profile?, request
      end
    end

    private

    def with_config options = {}
      original_config = Dial._configuration.instance_variable_get :@options
      new_config = original_config.merge options

      Dial._configuration.instance_variable_set :@options, new_config
      yield
    ensure
      Dial._configuration.instance_variable_set :@options, original_config
    end
  end
end
