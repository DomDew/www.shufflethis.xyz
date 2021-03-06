Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "pages#login"

  get "index", to: "pages#index"
  get "login", to: "pages#login"
  get "playlists", to: "pages#playlists"
  get "spotify_auth", to: "pages#spotify_auth"
  post "playlists", to: "pages#shuffle_playlist"
end
