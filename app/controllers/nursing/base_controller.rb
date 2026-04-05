class Nursing::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_staff!

  layout "nursing"

  private

  def current_establishment
    current_user.establishment
  end
  helper_method :current_establishment
end
