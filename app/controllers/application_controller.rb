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
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :establishment_id, :cpf, :birth_date, :phone ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :phone ])
  end

  def require_staff!
    unless staff_signed_in?
      flash[:alert] = "Acesso restrito à equipe."
      redirect_to new_staff_session_path
    end
  end

  def require_patient!
    unless patient_signed_in?
      flash[:alert] = "Acesso restrito a pacientes."
      redirect_to root_path
    end
  end

  def require_admin!
    unless user_signed_in? && current_user.admin?
      flash[:alert] = "Acesso restrito a administradores."
      redirect_to root_path
    end
  end
end
