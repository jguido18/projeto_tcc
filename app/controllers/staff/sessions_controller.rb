class Staff::SessionsController < Devise::SessionsController
  # Override to block non-staff users from accessing the staff login
  def create
    user = User.find_by(email: params.dig(:user, :email)&.downcase)

    if user && !user.staff?
      flash[:alert] = "Acesso não autorizado. Esta área é exclusiva para atendentes e médicos."
      redirect_to new_staff_session_path and return
    end

    super
  end

  protected

  def after_sign_in_path_for(resource)
    if resource.doctor?
      doctor_root_path
    else
      staff_root_path
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    new_staff_session_path
  end
end
