class Validation::PanelController < Validation::BaseController
  def index
    # Left column: sessions awaiting nursing validation
    @awaiting_validation = TriageSession
      .includes(:user, ai_classification: :triage_validation)
      .where(status: :awaiting_validation)
      .order(created_at: :asc)

    # Right column: validated sessions waiting in queue
    @priority_queue = QueueEntry
      .includes(triage_session: [ :user, { ai_classification: :triage_validation } ])
      .where(status: :waiting)
      .order(:urgency_weight, :queued_at)

    @total_waiting = @priority_queue.count
  end
end
