require "csv"

class Validation::ReportsController < Validation::BaseController
  before_action :require_admin!

  def index
    @period = params[:period].presence_in(%w[today week month]) || "today"
    @range  = period_range(@period)

    # ── Métricas do período ────────────────────────────────────────────
    @total_period    = TriageSession.where(created_at: @range).count
    @attended_period = TriageSession.where(status: :completed, finished_at: @range).count
    @waiting_now     = QueueEntry.where(status: :waiting).count
    @called_now      = QueueEntry.where(status: :called).count

    # ── Precisão da IA (geral, sem filtro de período) ──────────────────
    total_val    = TriageValidation.count
    adjusted_val = TriageValidation.where(decision: :adjusted).count
    @ai_accuracy_pct = total_val > 0 ?
      ((total_val - adjusted_val).to_f / total_val * 100).round(1) : nil

    # ── Direção dos erros da IA, entre os casos ajustados ───────────────
    # Subtriagem = IA classificou como MENOS urgente do que o colaborador decidiu
    # (peso final menor que o peso sugerido) — o erro clinicamente perigoso.
    # Sobretriagem = IA classificou como MAIS urgente — erro do lado seguro.
    adjusted = TriageValidation.adjusted.includes(:ai_classification)
    @undertriage_count = adjusted.count do |v|
      TriageSetting.current.urgency_weight_for(v.final_urgency_level) < v.ai_classification.urgency_weight
    end
    @overtriage_count = adjusted.count do |v|
      TriageSetting.current.urgency_weight_for(v.final_urgency_level) > v.ai_classification.urgency_weight
    end

    # ── Distribuição por urgência no período ──────────────────────────
    raw_urgency = QueueEntry.where(queued_at: @range).group(:urgency_level).count
    levels      = TriageSetting.current.urgency_levels
    @urgency_counts = raw_urgency

    @urgency_chart_data = {
      labels: levels.map { |l| l["label"] },
      values: levels.map { |l| raw_urgency[l["key"]] || 0 },
      colors: levels.map { |l| l["color"] }
    }

    # ── Tendência diária (últimos N dias conforme período) ────────────
    days = @period == "month" ? 30 : @period == "week" ? 7 : 7
    trend_range = (days - 1).days.ago.to_date..Date.today

    @daily_trend_data = {
      labels: trend_range.map { |d| d.strftime("%d/%m") },
      values: trend_range.map { |d|
        TriageSession
          .where(status: :completed,
                 finished_at: d.beginning_of_day..d.end_of_day)
          .count
      }
    }

    # ── Últimos 20 atendimentos concluídos ────────────────────────────
    @recent = TriageSession
      .includes(:user, ai_classification: :triage_validation)
      .where(status: :completed)
      .order(finished_at: :desc)
      .limit(20)
  end

  def export_csv
    sessions = TriageSession
      .includes(:user, ai_classification: :triage_validation)
      .where(status: :completed)
      .order(finished_at: :desc)

    csv_data = CSV.generate(headers: true, col_sep: ";", encoding: "UTF-8") do |csv|
      csv << [
        "Data/Hora", "Paciente", "E-mail",
        "Urgência IA", "Urgência Final", "Decisão do Colaborador", "Notas"
      ]

      sessions.each do |session|
        ai         = session.ai_classification
        validation = ai&.triage_validation
        final_level = validation&.final_urgency_level || ai&.urgency_level

        csv << [
          session.finished_at&.strftime("%d/%m/%Y %H:%M"),
          session.user.name,
          session.user.email,
          ai ? TriageSetting.current.urgency_label_for(ai.urgency_level) : "—",
          final_level ? TriageSetting.current.urgency_label_for(final_level) : "—",
          validation ? I18n.t("enums.triage_validation.decision.#{validation.decision}") : "—",
          validation&.notes.presence || "—"
        ]
      end
    end

    send_data "\xEF\xBB\xBF#{csv_data}",
              filename: "atendimentos_#{Date.today.strftime("%Y%m%d")}.csv",
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  private

  def period_range(period)
    case period
    when "today"  then Time.current.beginning_of_day..Time.current.end_of_day
    when "week"   then 6.days.ago.beginning_of_day..Time.current.end_of_day
    when "month"  then 29.days.ago.beginning_of_day..Time.current.end_of_day
    end
  end
end
