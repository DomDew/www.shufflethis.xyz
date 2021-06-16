class PagesController < ApplicationController
  def index
  end

  def spotify_auth
    @client_id = ENV['CLIENT_ID']
    raise
  end
end
