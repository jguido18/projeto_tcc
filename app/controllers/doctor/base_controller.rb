class Doctor::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_doctor!

  layout "doctor"

  private

  def require_doctor!
    unless user_signed_in? && current_user.doctor?
      flash[:alert] = t("app.flash.unauthorized_doctor")
      redirect_to new_staff_session_path
    end
  end

  def current_establishment
    current_user.establishment
  end
  helper_method :current_establishment
end
