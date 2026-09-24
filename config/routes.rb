Rails.application.routes.draw do
  devise_for :users
  namespace :employer do
    resources :jobs, only: :index do
      resources :applications, only: :index
    end
    resources :applications, only: :update
  end
  namespace :my do
    resources :applications, only: :index
    resources :saved_jobs, only: %i[index destroy]
    resources :notifications, only: %i[index update]
  end
  resources :jobs do
    patch :close, on: :member
    resources :applications, only: %i[new create]
    resources :saved_jobs, only: :create
  end
  resources :companies
  root "jobs#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
