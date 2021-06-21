require "base64"
require "json"

class PagesController < ApplicationController
  def index
    @code = params[:code]
    @redirect_uri = "http://localhost:3000/index"

    @token_response = request_token(@code, @redirect_uri)
    @access_token = JSON.parse(@token_response.data[:body])["access_token"]
    @refresh_token = JSON.parse(@token_response.data[:body])["refresh_token"]

    if @token_response[:status] == 400
      # If error response, then prompt user to login again
      redirect_to login_path, notice: "Oops, there has been a slight hickup. Please login again!"
    else
      # ** If token request successful, then redirect to playlist page.
      # This is necessary so that the page doesn't crash on page reload / loading flashes later. **
      redirect_to playlists_path(access_token: @access_token, refresh_token: @refresh_token)
    end
  end

  def playlists
    # ** Set tokens to corresponding params as instance variables for more readability in methods
    @access_token = params[:access_token]
    @refresh_token = params[:refresh_token]

    # ** Call user_playlists to create an array of playlist names and ids to display them in view
    # ** In view call post action to playlists (shuffle_playlist) to get playlist tracks on button click,
    # perform a weighted shuffle on the playlist and make put request to spotify API **
    user_playlists
  end

  def spotify_auth
    redirect_to build_auth_url
  end

  def shuffle_playlist
    # ** Weight tracks given length of playlist and track position in list,
    # then create new array with pickup gem **
    weight_tracks(playlist_track_uris)
    @shuffle_tracks = Pickup.new(@tracks_weighted, uniq: true)
    @tracks_shuffled = @shuffle_tracks.pick(@tracks_weighted.length)

    # ** Make put request to spotify API to overwrite playlist
    shufflethis_playlist(params[:access_token])

    # ** Handle response of Spotify API
    handle_shuffle_response
  end

  private

  # ** Build url for Spotify OAuth (get request)
  def build_auth_url
    @base_url = "https://accounts.spotify.com/authorize"
    @redirect_uri = "http://localhost:3000/index"

    @scope = "playlist-modify-public playlist-modify-private playlist-read-private playlist-read-collaborative"

    @url = "#{@base_url}?client_id=#{ENV['CLIENT_ID']}&response_type=code&redirect_uri=#{@redirect_uri}&show_dialog=true&scope=#{@scope}"
  end

  # Make post request for creating an access token
  def request_token(code, redirect_uri)
    Excon.post(
      "https://accounts.spotify.com/api/token",
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

  # Make post request to get new access token based on refresh token
  def refresh_access_token
    @refresh_response = Excon.post(
      "https://accounts.spotify.com/api/token",
      body: URI.encode_www_form(
        grant_type: "refresh_token",
        refresh_token: @refresh_token
      )
    )

    @access_token = JSON.parse(@refresh_response.data[:body])["access_token"]
    raise
  end

  # Make get request for current users playlists with access token
  def fetch_playlists
    Excon.get(
      "https://api.spotify.com/v1/me/playlists",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@access_token}"
      }
    )
  end

  # Select names and id's for users playlists from response
  def user_playlists
    @playlists = JSON.parse(fetch_playlists[:body])["items"]
    @playlists_names_ids = @playlists.map do |playlist|
      {
        playlist_id: playlist["id"],
        name: playlist["name"]
      }
    end
  end

  # Make get request for given playlist (on button click)
  def playlist
    Excon.get(
      "https://api.spotify.com/v1/playlists/#{params[:playlist_id]}",
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Authorization" => "Bearer #{params[:access_token]}"
      }
    )
  end

  # Create new Array containing the id's of the tracks
  def playlist_track_uris
    @playlist_return = playlist
    @playlist = JSON.parse(@playlist_return.data[:body])
    @playlist_track_uris = @playlist["tracks"]["items"].map { |track| track["track"]["uri"] }
  end

  # Create Hash to weight tracks dependent on the length of the playlist.
  # This isn't dry - Refactor to handle weight assignment in one iteration instead of three.
  # TODO: Add additional weight to tracks depending on when they have been added to the playlist
  def weight_tracks(track_uris)
    @tracks_weighted = {}

    if track_uris.length < 15
      track_ids.each do |track_uri|
        @tracks_weighted[track_uri] = 10
      end
      track_uris.first(3).each do |track_uri|
        @tracks_weighted[track_uri] = 8
      end
      track_uris.last(3).each do |track_uri|
        @tracks_weighted[track_uri] = 15
      end
    elsif track_uris.length >= 30
      track_uris.each do |track_uri|
        @tracks_weighted[track_uri] = 10
      end
      track_uris.first(10).each do |track_uri|
        @tracks_weighted[track_uri] = 8
      end
      track_uris.last(10).each do |track_uri|
        @tracks_weighted[track_uri] = 15
      end
    elsif track_uris.length >= 15
      track_uris.each do |track_uri|
        @tracks_weighted[track_uri] = 10
      end
      track_uris.first(5).each do |track_uri|
        @tracks_weighted[track_uri] = 8
      end
      track_uris.last(5).each do |track_uri|
        @tracks_weighted[track_uri] = 15
      end
    end
  end

  def shufflethis_playlist(access_token)
    @shuffle_response = Excon.put(
      "https://api.spotify.com/v1/playlists/#{params[:playlist_id]}/tracks",
      body: "{ \"uris\": #{@tracks_shuffled.to_json} }",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{access_token}"
      }
    )
  end

  def handle_shuffle_response
    case @shuffle_response[:status]
    when 201
      redirect_to playlists_path(
        access_token: params[:access_token],
        refresh_token: params[:refresh_token]
      ), notice: "Mixed it up real good!", remote: true
    when 401
      shufflethis_playlist(refresh_access_token)
      if @shuffle_response[:status] == 201
        @notice = "Mixed it up real good!"
      else
        @notice = "Oops! Something went wrong... Please try again!"
      end
      redirect_to playlists_path(
        access_token: params[:access_token],
        refresh_token: params[:refresh_token]
      ), notice: @notice, remote: true
    when 403
      redirect_to playlists_path(
        access_token: params[:access_token],
        refresh_token: params[:refresh_token]
      ), alert: "Wait... This isn't your playlist! Why would you shufflethis?", remote: true
    end
  end
end
