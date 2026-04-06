class TvController < ApplicationController
  # Tela pública — não exige autenticação
  skip_before_action :authenticate_user!, raise: false

  layout "tv"

  def show
    @called_entries = QueueEntry
      .includes(triage_session: :user)
      .where(status: :called)
      .order(:urgency_weight, :called_at)
  end
end
