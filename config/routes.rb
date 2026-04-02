Rails.application.routes.draw do
  # Patient login — /login, /register
  devise_for :users,
             path: "",
             path_names: { sign_in: "login", sign_out: "logout", sign_up: "register" }

  # Staff login — /staff/login (attendants, doctors, admins)
  # Uses custom controllers to enforce attendant/doctor/admin check before signing in
  devise_scope :user do
    get  "staff/login",  to: "staff/sessions#new",    as: :new_staff_session
    post "staff/login",  to: "staff/sessions#create",  as: :staff_session
    delete "staff/logout", to: "staff/sessions#destroy", as: :destroy_staff_session
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "home#index"
end
