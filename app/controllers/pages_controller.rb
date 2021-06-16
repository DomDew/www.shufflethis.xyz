class PagesController < ApplicationController
  def index
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
