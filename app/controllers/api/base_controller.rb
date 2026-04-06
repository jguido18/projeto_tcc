class Api::BaseController < ApplicationController
  # A API nunca deve redirecionar — sempre retorna JSON
  respond_to :json

  before_action :authenticate_api_user!
  before_action :require_api_patient!

  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "Token inválido" }, status: :unprocessable_entity
  end

  private

  # Sobrescreve o authenticate_user! do Devise para retornar JSON
  def authenticate_api_user!
    unless user_signed_in?
      render json: { error: "Não autenticado. Faça login novamente." }, status: :unauthorized
    end
  end

  # Sobrescreve require_patient! para retornar JSON
  def require_api_patient!
    unless user_signed_in? && current_user.patient?
      render json: { error: "Acesso restrito a solicitantes." }, status: :forbidden
    end
  end
end
