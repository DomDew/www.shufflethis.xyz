require "base64"

class PagesController < ApplicationController
  def index
    @code = params[:code]
    @redirect_uri = "http://localhost:3000/index"

    @token_response = request_token(@code, @redirect_uri)
    @access_token = JSON.parse(@token_response.data[:body])["access_token"]

    if @token_response[:status] == 400
      redirect_to login_path, notice: "Oops, there has been a slight hickup. Please login again!"
    else
      get_user_playlists
    end
  end

  def spotify_auth
    redirect_to build_auth_url
  end

  def shuffle_playlist
    @playlist_return = get_playlist
    @playlist = JSON.parse(@playlist_return.data[:body])

    raise

    # resort tracks in playlist

    # post updated list to spotify

    # if status 401 --> refresh token
    # if status 403 --> You are not allowed
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

  def fetch_playlists
    Excon.get("https://api.spotify.com/v1/me/playlists",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@access_token}"
      }
      )
  end

  def get_user_playlists
    @token_hash = JSON.parse(@token_response.data[:body])

      @playlists = JSON.parse(fetch_playlists[:body])["items"]
      @playlists_names_ids = @playlists.map do |playlist|
        {
          playlist_id: playlist["id"],
          name: playlist["name"]
        }
      end
  end

  def get_playlist
    Excon.get("https://api.spotify.com/v1/playlists/#{params[:playlist_id]}",
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Authorization" => "Bearer #{params[:access_token]}"
        }
      )
  end
end
