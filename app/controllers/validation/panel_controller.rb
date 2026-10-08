class Validation::PanelController < Validation::BaseController
  def index
    # Left column: sessions awaiting colaborador validation
    @awaiting_validation = TriageSession
      .includes(:user, ai_classification: :triage_validation)
      .where(status: :awaiting_validation)
      .order(created_at: :asc)

    # Right column: validated sessions waiting in queue
    @priority_queue = QueueEntry.waiting_ordered_with_aging(
      QueueEntry.includes(triage_session: [ :user, { ai_classification: :triage_validation } ]).waiting
    )

    @total_waiting = @priority_queue.count

    # Sem validação da equipe a coluna da esquerda fica sempre vazia — mas se
    # ainda sobrou triagem pendente de antes da mudança, ela continua visível
    # para ninguém ficar preso nela.
    @show_validation_column = TriageSetting.current.require_staff_validation? || @awaiting_validation.any?

    # Triagens feitas (às vezes de casa) esperando a pessoa chegar no local.
    @awaiting_checkin = TriageSession
      .includes(:user, :ai_classification)
      .where(status: :awaiting_checkin)
      .order(finished_at: :asc)
    @show_checkin_section = TriageSetting.current.require_checkin? || @awaiting_checkin.any?
  end
end
