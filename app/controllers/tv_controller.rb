class TvController < ApplicationController
  # Tela pública — não exige autenticação
  skip_before_action :authenticate_user!, raise: false

  layout "tv"

  def show
    @establishment = Establishment.find(params[:establishment_id])
    @called_entries = QueueEntry
      .includes(triage_session: :user)
      .where(establishment: @establishment, status: :called)
      .order(:urgency_weight, :called_at)
  rescue ActiveRecord::RecordNotFound
    render plain: "Estabelecimento não encontrado.", status: :not_found
  end
end
