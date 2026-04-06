Rails.application.routes.draw do
  # Patient login — /login, /register
  devise_for :users,
             path: "",
             path_names: { sign_in: "login", sign_out: "logout", sign_up: "register" },
             controllers: { registrations: "registrations" }

  # Staff login — /staff/login (colaboradors and admins)
  # Uses custom controller to enforce colaborador/admin permission before signing in
  devise_scope :user do
    get  "staff/login",  to: "staff/sessions#new",    as: :new_staff_session
    post "staff/login",  to: "staff/sessions#create",  as: :staff_session
    delete "staff/logout", to: "staff/sessions#destroy", as: :destroy_staff_session
  end

  # API JSON para o app Vue do paciente
  namespace :api do
    get  "session",          to: "session#show"
    post "triage/start",     to: "triage#start"
    get  "triage/status",    to: "triage#status"
    get  "triage/messages",  to: "triage#messages"
    post "triage/message",   to: "triage#send_message"
    post "triage/finish",    to: "triage#finish"
    post "triage/restart",   to: "triage#restart"
  end

  # Shell Vue — serve o SPA para o paciente (todas as rotas /app/*)
  get "/app", to: "patient_app#index", as: :patient_app
  get "/app/*path", to: "patient_app#index"

  # Manter rotas antigas funcionando (redirecionam para o app Vue)
  get  "/triage/identification", to: redirect("/app")
  get  "/triage/chat",           to: redirect("/app/chat")
  get  "/triage/queue",          to: redirect("/app/queue")

  # Validation flow — staff only
  namespace :validation do
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


  namespace :admin do
    resource :triage_setting, only: [ :edit, :update ]
    resources :users, only: [ :index, :new, :create, :edit, :update, :destroy ]
  end

  # TV pública de fila — sem autenticação
  get "tv", to: "tv#show", as: :queue_tv

  # Attendance flow — staff only
  namespace :attendance do
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
