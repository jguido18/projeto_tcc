class Doctor::PanelController < Doctor::BaseController
  def index
    # Pacientes que foram chamados pela enfermagem e aguardam o médico
    @called_entries = QueueEntry
      .includes(triage_session: [ :user, { ai_classification: :triage_validation }, :chat_messages ])
      .where(establishment: current_establishment, status: :called)
      .order(:urgency_weight, :called_at)
  end
end
