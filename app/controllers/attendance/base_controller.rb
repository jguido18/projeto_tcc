class Attendance::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_doctor!

  layout "attendance"

  private

  def require_doctor!
    unless user_signed_in? && current_user.doctor?
      flash[:alert] = t("app.flash.unauthorized_doctor")
      redirect_to new_staff_session_path
    end
  end
end
