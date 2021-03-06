require "base64"
require "json"

class PagesController < ApplicationController
  # ** Initial get request when user clicks "login with spotify" button (redirects user to index page, where index method will be triggered)
  def spotify_auth
    redirect_to build_auth_url
  end

  # ** Take code that has been returned from initial call to spotify API and get access and refresh token from spotify
  def index
    @code = params[:code]
    @redirect_uri = ENV['REDIRECT_URI']

    @token_response = request_token(@code, @redirect_uri)
    @access_token = JSON.parse(@token_response.data[:body])["access_token"]
    @refresh_token = JSON.parse(@token_response.data[:body])["refresh_token"]

    if @token_response[:status] == 400
      # If error response, then prompt user to login again
      redirect_to login_path, notice: "Oops, there has been a slight hickup. Please login again!"
    else
      # ** If token request successful, then redirect to playlist page.
      # The redirect is necessary so that the page doesn't crash on page reload / loading flashes later. **
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

  def shuffle_playlist
    # ** Weight tracks given length of playlist and track position in list,
    # then create new array with pickup gem **
    weight_tracks(playlist_track_uris)
    @shuffle_tracks = Pickup.new(@tracks_weighted, uniq: true)
    @tracks_shuffled = @shuffle_tracks.pick(@tracks_weighted.length)

    # ** Make put request to spotify API to overwrite playlist, unless it is longer than 100 tracks, to not delete tracks from the playlist.
    if @tracks_shuffled.length >= 100
      redirect_to playlists_path(
        access_token: params[:access_token],
        refresh_token: params[:refresh_token]
      ),
        alert: "Sorry, '#{@playlist["name"]}' has too many tracks... we tried really hard, but we can't shufflethis...",
        remote: true
    else
      shufflethis_playlist(params[:access_token])
      # ** Handle response of Spotify API
      handle_shuffle_response
    end
  end

  private

  # ** Build url for Spotify OAuth (get request)
  def build_auth_url
    @base_url = "https://accounts.spotify.com/authorize"
    @redirect_uri = ENV['REDIRECT_URI']

    @scope = "playlist-modify-public playlist-modify-private playlist-read-private playlist-read-collaborative"

    @url = "#{@base_url}?client_id=#{ENV['CLIENT_ID']}&response_type=code&redirect_uri=#{@redirect_uri}&show_dialog=true&scope=#{@scope}"
  end

  # ** Make post request for creating an access token
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

  # ** Make post request to get new access token based on refresh token
  def refresh_access_token
    @refresh_response = Excon.post(
      "https://accounts.spotify.com/api/token",
      body: URI.encode_www_form(
        grant_type: "refresh_token",
        refresh_token: params[:refresh_token]
      ),
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Authorization" => "Basic #{Base64.strict_encode64("#{ENV['CLIENT_ID']}:#{ENV['CLIENT_SECRET']}")}"
      }
    )

    @access_token = JSON.parse(@refresh_response.data[:body])["access_token"]
  end

  # ** Select names and id's for users playlists from response
  def user_playlists
    @playlists = JSON.parse(fetch_playlists[:body])["items"]
    @playlists_names_ids = @playlists.map do |playlist|
      {
        playlist_id: playlist["id"],
        name: playlist["name"]
      }
    end
  end

  # ** Make get request for current users playlists with access token
  def fetch_playlists
    Excon.get(
      "https://api.spotify.com/v1/me/playlists?limit=50",
      headers: {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@access_token}"
      }
    )
  end

  # ** Create new Array containing the id's of the tracks of a clicked playlist
  def playlist_track_uris
    @playlist_return = playlist
    @playlist = JSON.parse(@playlist_return.data[:body])
    @playlist_track_uris = @playlist["tracks"]["items"].map { |track| track["track"]["uri"] }
  end

  # ** Make get request for given playlist (on button click) and handle response status (refresh token if needed)
  def playlist
    @playlist_response = fetch_playlist(params[:access_token])

    case @playlist_response.status
    when 401 then fetch_playlist(refresh_access_token)
    when 200 then @playlist_response
    end
  end

  # ** Get request for clicked playlist
  def fetch_playlist(access_token)
    Excon.get(
      "https://api.spotify.com/v1/playlists/#{params[:playlist_id]}",
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
        "Authorization" => "Bearer #{access_token}"
      }
    )
  end

  # ** Create Hash to weight tracks dependent on the length of the playlist.
  # !!! This isn't dry - Refactor to handle weight assignment in one iteration instead of three.
  # !!! TODO: Add additional weight to tracks depending on when they have been added to the playlist
  def weight_tracks(track_uris)
    @tracks_weighted = {}

    if track_uris.length < 15
      track_uris.each do |track_uri|
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

  # ** Overwrite playlist content with newly shuffled tracks
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

  # ** Give feedback to user / progress given the status of the response of the API
  def handle_shuffle_response
    case @shuffle_response[:status]
    when 201
      redirect_to playlists_path(
        access_token: params[:access_token],
        refresh_token: params[:refresh_token]
      ), notice: "Mixed up '#{@playlist["name"]}' real good!", remote: true
    when 401
      # ** Refresh token if token is expired (401), then shuffle playlist again
      shufflethis_playlist(refresh_access_token)
      if @shuffle_response[:status] == 201
        @notice = "Mixed up '#{@playlist["name"]}' real good!"
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
      ), alert: "Wait... '#{@playlist["name"]}' isn't your playlist! Why would you shufflethis?", remote: true
    end
  end
end
