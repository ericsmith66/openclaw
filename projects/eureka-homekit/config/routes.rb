Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API endpoints
  namespace :api do
    post "homekit/events", to: "homekit_events#create"
    resources :floorplans, only: [ :show ]
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Sync trigger
  resource :sync, only: [ :create ]

  # Defines the root path route ("/")
  root "dashboards#show"
  resource :dashboard, only: [ :show ]

  resources :homes, only: [ :index, :show ] do
    resources :rooms, only: [ :index ], module: :homes
  end
  resources :rooms, only: [ :index, :show ]
  resources :sensors, only: [ :index, :show ]
  resources :events, only: [ :index, :show ]
  resources :scenes, only: [ :index, :show ] do
    member do
      post :execute
    end
  end

  resources :accessories, only: [] do
    collection do
      post :control
      post :batch_control
    end
  end
  post "accessories/batch_control", to: "accessories#batch_control", as: :accessories_batch_control

  resources :favorites, only: [ :index ] do
    collection do
      post :toggle
      patch :reorder
    end
  end

  # Mount ActionCable at /cable
  mount ActionCable.server => "/cable"
end
