class PatientAppController < ApplicationController
  before_action :authenticate_user!
  before_action :require_patient!

  layout "patient_app"

  # Serve o shell HTML do SPA Vue.
  # O Vue Router cuida da navegação interna (/app/chat, /app/queue…).
  def index
  end
end
