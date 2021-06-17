require "base64"

class PagesController < ApplicationController
  def index
    if params[:code].present?
      @code = params[:code]
      @redirect_uri = "http://localhost:3000/index"

      @token_response = request_token(@code, @redirect_uri)
      @token_hash = JSON.parse(@token_response.data[:body])

      @playlists = JSON.parse(get_playlists(@token_hash["access_token"])[:body])["items"]
      @playlists_names_ids = @playlists.map do |playlist|
        {
          id: playlist["id"],
          name: playlist["name"]
        }
      end
    end
  end

  def spotify_auth
    redirect_to build_auth_url
  end

  private

  def build_auth_url
    @base_url = "https://accounts.spotify.com/authorize"
    @redirect_uri = "http://localhost:3000/index"

    @scope = "playlist-modify-public playlist-modify-private playlist-read-private playlist-read-collaborative"

    @url = "#{@base_url}?client_id=#{ENV['CLIENT_ID']}&response_type=code&redirect_uri=#{@redirect_uri}&show_dialog=true&scope=#{@scope}"
  end

  def request_token(code, redirect_uri)
    Excon.post("https://accounts.spotify.com/api/token",
      body: URI.encode_www_form(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        ),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Authorization" => "Basic #{Base64.strict_encode64("#{ENV['CLIENT_ID']}:#{ENV['CLIENT_SECRET']}")}"
        }
      )
  end

  def get_playlists(access_token)
    Excon.get("https://api.spotify.com/v1/me/playlists",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{access_token}"
      }
      )
  end
end
