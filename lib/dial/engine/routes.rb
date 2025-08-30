# frozen_string_literal: true

require "uri"

Dial::Engine.routes.draw do
  scope path: "/dial", as: "dial" do
    get "profile", to: lambda { |env|
      query_params = URI.decode_www_form(env[::Rack::QUERY_STRING]).to_h
      uuid = query_params["uuid"]
      unless uuid && uuid.match?(/\A[0-9a-fA-F-]+_vernier\z/)
        return [
          400,
          { "Content-Type" => "text/plain" },
          ["Bad Request"]
        ]
      end

      profile_key = "#{uuid}:profile"

      begin
        content = Dial::Storage.fetch profile_key
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
end
