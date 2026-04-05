Rails.application.routes.draw do
  # Patient login — /login, /register
  devise_for :users,
             path: "",
             path_names: { sign_in: "login", sign_out: "logout", sign_up: "register" },
             controllers: { registrations: "registrations" }

  # Staff login — /staff/login (attendants, doctors, admins)
  # Uses custom controllers to enforce attendant/doctor/admin check before signing in
  devise_scope :user do
    get  "staff/login",  to: "staff/sessions#new",    as: :new_staff_session
    post "staff/login",  to: "staff/sessions#create",  as: :staff_session
    delete "staff/logout", to: "staff/sessions#destroy", as: :destroy_staff_session
  end

  # Patient triage flow
  resource :triage, only: [] do
    get  :identification
    post :start
    get  :chat
    post :message
    get  :queue
  end

  # Nursing flow — staff only
  namespace :nursing do
    root to: "panel#index"
    resources :triage_validations, only: [ :new, :create ]
    resources :queue_entries, only: [] do
      member do
        patch :call
        patch :finish
      end
    end
    get :reports, to: "reports#index"
  end

  # TV pública de fila — sem autenticação
  get "tv/:establishment_id", to: "tv#show", as: :queue_tv

  # Doctor flow — doctors only
  namespace :doctor do
    root to: "panel#index"
    resources :attendances, only: [ :show ] do
      member do
        patch :finish
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "home#index"
end
