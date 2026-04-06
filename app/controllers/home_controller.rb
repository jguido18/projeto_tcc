class HomeController < ApplicationController
  def index
    # Paciente autenticado vai direto para o app Vue
    if user_signed_in? && current_user.patient?
      redirect_to patient_app_path and return
    end

    # Staff vai para seu painel
    if user_signed_in? && current_user.colaborador?
      redirect_to validation_root_path and return
    end

    if user_signed_in? && current_user.specialist?
      redirect_to attendance_root_path and return
    end

    if user_signed_in? && current_user.admin?
      redirect_to edit_admin_triage_setting_path and return
    end
  end
end
