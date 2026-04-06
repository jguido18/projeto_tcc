class Api::SessionController < ApplicationController
  # GET /api/session — retorna dados do usuário logado para o Vue
  def show
    if user_signed_in?
      render json: {
        logged_in:  true,
        id:         current_user.id,
        name:       current_user.name,
        email:      current_user.email,
        is_patient: current_user.patient?,
        is_staff:   current_user.staff?,
        csrf_token: form_authenticity_token
      }
    else
      render json: { logged_in: false }
    end
  end
end
