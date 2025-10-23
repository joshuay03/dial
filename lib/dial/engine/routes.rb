# frozen_string_literal: true

require "uri"

Dial::Engine.routes.draw do
  get "/profile", to: lambda { |env|
    query_params = URI.decode_www_form(env[::Rack::QUERY_STRING]).to_h
    profile_key = query_params["key"]
    unless profile_key && profile_key.match?(/\A[0-9a-f-]+_vernier\z/i)
      return [
        400,
        { "Content-Type" => "text/plain" },
        ["Bad Request"]
      ]
    end

    profile_storage_key = Dial::Storage.profile_storage_key profile_key
    begin
      content = Dial::Storage.fetch profile_storage_key
      if content
        [
          200,
          { "Content-Type" => "application/json", "Access-Control-Allow-Origin" => Dial::VERNIER_VIEWER_URL },
          [content]
        ]
      else
        [
          404,
          { "Content-Type" => "text/plain" },
          ["Not Found"]
        ]
      end
    rescue
      [
        500,
        { "Content-Type" => "text/plain" },
        ["Internal Server Error"]
      ]
    end
  }
end
