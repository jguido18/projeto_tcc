class Validation::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_staff!

  layout "validation"
end
