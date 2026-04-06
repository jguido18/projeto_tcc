class Attendance::PanelController < Attendance::BaseController
  def index
    # Solicitantes chamados pela equipe de validação e aguardando atendimento.
    @called_entries = QueueEntry
      .includes(triage_session: [ :user, { ai_classification: :triage_validation }, :chat_messages ])
      .where(status: :called)
      .order(:urgency_weight, :called_at)
  end
end
