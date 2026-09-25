Rails.application.routes.draw do
  devise_for :users
  devise_scope :user do
    get "employers/sign_up", to: "employer_registrations#new", as: :new_employer_registration
    post "employers", to: "employer_registrations#create", as: :employer_registration
  end
  namespace :admin do
    root to: "users#index"
    resources :users, only: %i[index show destroy] do
      patch :approve, on: :member
      patch :decline, on: :member
    end
    resources :companies, only: %i[index show destroy]
    resources :jobs, only: %i[index destroy] do
      patch :close, on: :member
    end
    resources :applications, only: %i[index show]
  end
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
    get "job_alerts", to: "job_alerts#edit"
    patch "job_alerts", to: "job_alerts#update"
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
