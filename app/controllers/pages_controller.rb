require "base64"

class PagesController < ApplicationController
  def index
    if params[:code].present?
      @code = params[:code]
      @redirect_uri = "http://localhost:3000/index"

      @token_response = Excon.post("https://accounts.spotify.com/api/token",
        body: URI.encode_www_form(
          grant_type: "authorization_code",
          code: @code,
          redirect_uri: @redirect_uri,
          client_id: ENV['CLIENT_ID'],
          client_secret: ENV['CLIENT_SECRET']
          ),
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          }
        )

      @token_hash = JSON.parse(@token_response.data[:body])
    end
  end

  def spotify_auth
    redirect_to build_auth_url
  end

  private

  def build_auth_url
    @base_url = "https://accounts.spotify.com/authorize"
    @redirect_uri = "http://localhost:3000/index"

    @client_id = ENV['CLIENT_ID']
    @client_secret = ENV['CLIENT_SECRET']

    @scope = "playlist-modify-public playlist-modify-private playlist-read-private playlist-read-collaborative"

    @url = "#{@base_url}?client_id=#{@client_id}&response_type=code&redirect_uri=#{@redirect_uri}&show_dialog=true&scope=#{@scope}"
  end
end
