Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "games#new"

  resources :games, only: %i[create show], param: :code do
    post :start, on: :member
    resources :cups, only: [] do
      patch :swap, on: :member
      post :start, on: :member
    end
    resources :races, only: [] do
      post :start, on: :member
      post :finish, on: :member
    end
    resources :checks, only: :update do
      post :contest, on: :member
    end
    resources :disputes, only: [] do
      member do
        post :decide
        post :start_vote
        post :close_vote
        post :vote
      end
    end
    resources :players, only: [] do
      member do
        post :abandon
        post :reinstate
      end
    end
    resources :duos, only: :update
  end
  resources :joins, only: :create
end
