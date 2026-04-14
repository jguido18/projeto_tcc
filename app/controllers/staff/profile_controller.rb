class Staff::ProfileController < ApplicationController
  before_action :authenticate_user!, :require_staff!

  layout -> { current_user.specialist? ? "attendance" : "validation" }

  def edit; end

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
      flash[:notice] = "Perfil atualizado com sucesso."
      redirect_to staff_edit_profile_path
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :phone, :birth_date, :cpf, :avatar, :email, :password, :password_confirmation, :current_password)
  end
end
