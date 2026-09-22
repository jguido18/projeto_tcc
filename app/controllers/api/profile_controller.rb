class Api::ProfileController < Api::BaseController
  def show
    avatar_url = current_user.avatar.attached? ? url_for(current_user.avatar) : nil

    render json: {
      name: current_user.name,
      email: current_user.email,
      phone: current_user.phone,
      birth_date: current_user.birth_date,
      cpf: current_user.cpf,
      avatar_url: avatar_url,
      pcd: current_user.pcd,
      height_cm: current_user.height_cm,
      weight_kg: current_user.weight_kg,
      bmi: current_user.bmi,
      obeso: current_user.obeso?,
      mobilidade_reduzida: current_user.mobilidade_reduzida,
      gestante: current_user.gestante,
      gestante_valid_until: current_user.gestante_valid_until,
      lactante: current_user.lactante,
      lactante_valid_until: current_user.lactante_valid_until,
      crianca_de_colo: current_user.crianca_de_colo,
      crianca_de_colo_valid_until: current_user.crianca_de_colo_valid_until,
      sms_notifications_enabled: current_user.sms_notifications_enabled
    }
  end

  def update
    changing_credentials = params.dig(:user, :email).present? &&
                           params.dig(:user, :email) != current_user.email ||
                           params.dig(:user, :password).present?

    success = if changing_credentials
      current_user.update_with_password(profile_params)
    else
      current_user.update(profile_params.except(:current_password, :password, :password_confirmation))
    end

    if success
      avatar_url = current_user.avatar.attached? ? url_for(current_user.avatar) : nil
      render json: { success: true, name: current_user.name, email: current_user.email, avatar_url: avatar_url }
    else
      render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(
      :name, :phone, :birth_date, :avatar, :email, :password, :password_confirmation, :current_password,
      :pcd, :mobilidade_reduzida, :height_cm, :weight_kg,
      :gestante, :gestante_valid_until,
      :lactante, :lactante_valid_until,
      :crianca_de_colo, :crianca_de_colo_valid_until,
      :sms_notifications_enabled
    )
  end
end
