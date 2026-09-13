Rails.application.routes.draw do
  resources :sources do
    member do
      post :test
    end
    collection do
      get :geocode
    end
  end

  resources :dashboard_items do
    member do
      patch :reposition
    end
  end

  resources :devices do
    member { post :refresh }
    # Self-enrollment: a panel with no token posts here to get one.
    collection { post :enroll, to: "enrollments#create" }
  end

  resources :device_dashboards, only: %i[create destroy]

  resources :dashboards, except: :show do
    resource :thumbnail, only: :show, module: :dashboards
  end
  # The builder is a dashboard's new and edit page, and the list's cards
  # stand in for a show page. Old links to either land in the builder.
  get "dashboards/:id",         to: redirect("/dashboards/%{id}/edit"), constraints: { id: /\d+/ }
  get "dashboards/:id/builder", to: redirect("/dashboards/%{id}/edit")
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboards#index"
  get "devices/:token/frame", to: "frames#show", as: :device_frame
  get "render/dashboard",     to: "renders#dashboard"
end
