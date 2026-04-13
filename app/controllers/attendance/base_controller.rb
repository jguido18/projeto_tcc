class Attendance::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_specialist!

  layout "attendance"

  private

  def require_specialist!
    unless user_signed_in? && (current_user.specialist? || current_user.admin?)
      flash[:alert] = t("app.flash.unauthorized_specialist")
      redirect_to new_staff_session_path
    end
  end
end
