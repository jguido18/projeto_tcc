class HomeController < ApplicationController
  def index
    # Paciente autenticado vai direto para o app Vue
    if user_signed_in? && current_user.patient?
      redirect_to patient_app_path and return
    end

    # Staff vai para seu painel
    if user_signed_in? && current_user.attendant?
      redirect_to nursing_root_path and return
    end

    if user_signed_in? && current_user.doctor?
      redirect_to doctor_root_path and return
    end
  end
end
