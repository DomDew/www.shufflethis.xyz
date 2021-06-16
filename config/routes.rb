Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root "pages#index"

  get "index", to: "pages#index"
  get "spotify_auth", to: "pages#spotify_auth"
end
