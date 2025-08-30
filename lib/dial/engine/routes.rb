# frozen_string_literal: true

Dial::Engine.routes.draw do
  scope path: "/dial", as: "dial" do
    get "profile", to: lambda { |env|
      uuid = env[::Rack::QUERY_STRING].sub "uuid=", ""

      # Validate UUID format (should end with _vernier)
      unless uuid.match?(/\A[0-9a-f-]+_vernier\z/)
        return [
          400,
          { "Content-Type" => "text/plain" },
          ["Bad Request"]
        ]
      end

      path = String ::Rails.root.join Dial::VERNIER_PROFILE_OUT_RELATIVE_DIRNAME, (uuid + Dial::VERNIER_PROFILE_OUT_FILE_EXTENSION)

      if File.exist? path
        begin
          content = File.read path
          [
            200,
            { "Content-Type" => "application/json", "Access-Control-Allow-Origin" => Dial::VERNIER_VIEWER_URL },
            [content]
          ]
        rescue
          [
            500,
            { "Content-Type" => "text/plain" },
            ["Internal Server Error"]
          ]
        end
      else
        [
          404,
          { "Content-Type" => "text/plain" },
          ["Not Found"]
        ]
      end
    }
  end
end
