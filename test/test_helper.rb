# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path "../lib", __dir__

require "dial"
require "app"

require "minitest/mock"
require "minitest/autorun"

require "rails/dom/testing"
require "rails/dom/testing/railtie"

module Dial
  class Test < Minitest::Test
    include Rack::Test::Methods
    include Rails::Dom::Testing::Assertions

    def teardown
      Dial.instance_variable_set :@_configuration, nil
      ActiveSupport::Dependencies.autoload_paths = []
      ActiveSupport::Dependencies.autoload_once_paths = []
    end

    private

    def document_root_element
      Rails::Dom::Testing.html_document.parse(last_response.body).root
    end
  end
end

Minitest.after_run do
  FileUtils.rm_rf Rails.root.join "log"
  FileUtils.rm_rf Rails.root.join "tmp"
end
