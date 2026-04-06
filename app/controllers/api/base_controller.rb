class Api::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_patient!

  # Retorna erros em JSON em vez de redirecionar
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "Token inválido" }, status: :unprocessable_entity
  end
end
