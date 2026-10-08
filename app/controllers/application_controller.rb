class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :staff_signed_in?, :patient_signed_in?

  def staff_signed_in?
    user_signed_in? && current_user.staff?
  end

  def patient_signed_in?
    user_signed_in? && current_user.patient?
  end

  protected

  def set_locale
    I18n.locale = :"pt-BR"
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :name, :cpf, :birth_date, :phone,
      :pcd, :mobilidade_reduzida, :height_cm, :weight_kg,
      :gestante, :gestante_valid_until,
      :lactante, :lactante_valid_until,
      :crianca_de_colo, :crianca_de_colo_valid_until,
      :sms_notifications_enabled
    ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :phone, :birth_date, :avatar, :sms_notifications_enabled ])
  end

  def require_staff!
    unless staff_signed_in?
      flash[:alert] = "Acesso restrito à equipe."
      redirect_to new_staff_session_path
    end
  end

  def require_patient!
    unless patient_signed_in?
      flash[:alert] = "Acesso restrito a solicitantes."
      redirect_to root_path
    end
  end

  def require_admin!
    unless user_signed_in? && current_user.admin?
      flash[:alert] = "Acesso restrito a administradores."
      redirect_to root_path
    end
  end

  # Após o login, direciona para o destino correto conforme perfil
  def after_sign_in_path_for(resource)
    if resource.patient?
      # Volta para onde ia (ex.: link do QR de check-in /app/queue?checkin=...),
      # desde que seja uma tela do app do paciente.
      stored = stored_location_for(resource)
      stored&.start_with?("/app") ? stored : patient_app_path
    elsif resource.admin?
      edit_admin_triage_setting_path
    elsif resource.colaborador?
      validation_root_path
    elsif resource.specialist?
      attendance_root_path
    else
      root_path
    end
  end
end
