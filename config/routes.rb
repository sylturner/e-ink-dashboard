Rails.application.routes.draw do
  resources :sources do
    member do
      post :test
    end
    collection do
      get :geocode
    end
  end

  # A note's phone page, opened from a panel's QR code or an NFC tag. A
  # shorter link lands on it too.
  resources :notes, only: %i[edit update]
  get "notes/:id", to: redirect("/notes/%{id}/edit"), constraints: { id: /\d+/ }

  resources :dashboard_items do
    member do
      patch :reposition
    end
  end

  resources :devices, except: :show do
    member { post :refresh }
    # Read-only, for the admin pages.
    resource :last_frame, only: :show, module: :devices
  end
  # A device's edit page is its home. Old links to a show page land there.
  get "devices/:id", to: redirect("/devices/%{id}/edit"), constraints: { id: /\d+/ }

  resources :device_dashboards, only: %i[create destroy]

  resources :dashboards, except: :show do
    resource :thumbnail, only: :show, module: :dashboards
  end
  # The builder is a dashboard's new and edit page, and the list's cards
  # stand in for a show page. Old links to either land in the builder.
  get "dashboards/:id",         to: redirect("/dashboards/%{id}/edit"), constraints: { id: /\d+/ }
  get "dashboards/:id/builder", to: redirect("/dashboards/%{id}/edit")
  # The app's one settings row: an edit page and nothing else.
  resource :settings, only: %i[edit update]
  get "settings", to: redirect("/settings/edit")

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboards#index"
  get "render/dashboard", to: "renders#dashboard"

  # The panels' API: TRMNL's BYOS protocol, spoken by TRMNL's own panels
  # and the sketch in esp32/. Deliberately unauthenticated (see
  # Api::BaseController).
  namespace :api do
    get  "setup",      to: "setups#show"
    get  "display",    to: "displays#show"
    post "log",        to: "logs#create"
    get  "images/:id", to: "images#show", as: :image
  end
end
