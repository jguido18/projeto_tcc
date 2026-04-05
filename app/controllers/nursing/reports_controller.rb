class Nursing::ReportsController < Nursing::BaseController
  def index
    today = Time.current.beginning_of_day..Time.current.end_of_day

    # ── Contadores do dia ──────────────────────────────────────────────
    @total_today = TriageSession
      .where(establishment: current_establishment, created_at: today)
      .count

    @attended_today = TriageSession
      .where(establishment: current_establishment, status: :completed, finished_at: today)
      .count

    @waiting_now = QueueEntry
      .where(establishment: current_establishment, status: :waiting)
      .count

    @called_now = QueueEntry
      .where(establishment: current_establishment, status: :called)
      .count

    # ── Distribuição por urgência (hoje) ───────────────────────────────
    # { "red" => 3, "yellow" => 5, ... }
    @urgency_counts = QueueEntry
      .where(establishment: current_establishment, queued_at: today)
      .group(:urgency_level)
      .count

    # ── Últimos 20 atendimentos concluídos ─────────────────────────────
    @recent = TriageSession
      .includes(:user, ai_classification: :triage_validation)
      .where(establishment: current_establishment, status: :completed)
      .order(finished_at: :desc)
      .limit(20)

    # ── Taxa de ajuste da IA (percentual de validações que alteraram a urgência)
    total_validations = TriageValidation
      .joins(:ai_classification)
      .where(ai_classifications: { triage_session_id:
        TriageSession.where(establishment: current_establishment).select(:id) })
      .count

    adjusted_validations = TriageValidation
      .joins(:ai_classification)
      .where(
        decision: :adjusted,
        ai_classifications: { triage_session_id:
          TriageSession.where(establishment: current_establishment).select(:id) }
      )
      .count

    @ai_accuracy_pct = total_validations > 0 ?
      ((total_validations - adjusted_validations).to_f / total_validations * 100).round(1) :
      nil
  end
end
