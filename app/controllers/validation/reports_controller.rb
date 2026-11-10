require "csv"

class Validation::ReportsController < Validation::BaseController
  before_action :require_admin!
  before_action :load_filters

  PERIODS = %w[today week month].freeze
  MAX_RANGE_DAYS = 366
  RECENT_LIMIT = 50

  def index
    sessions = filtered_sessions

    # ── Métricas do período (respeitam data e colaborador) ─────────────
    @total_period    = sessions.where(created_at: @range).count
    @attended_period = sessions.where(status: :completed, finished_at: @range).count

    # Fila agora — foto do momento, não depende do filtro
    @waiting_now = QueueEntry.where(status: :waiting).count
    @called_now  = QueueEntry.where(status: :called).count

    # ── Precisão da IA: validações feitas no período (e pelo colaborador) ─
    validations  = TriageValidation.where(validated_at: @range)
    validations  = validations.where(user_id: @staff_member.id) if @staff_member
    # A concordância compara o nível sugerido pela IA com o nível final da equipe
    # (e não o campo `decision`, que em registros antigos podia vir "confirmado"
    # mesmo com o nível alterado).
    compared = validations.includes(:ai_classification).reject { |v| v.rejected? || v.ai_classification.nil? }
    total_val = compared.size
    agreed    = compared.count { |v| v.final_urgency_level == v.ai_classification.urgency_level }
    @ai_accuracy_pct = total_val > 0 ? (agreed.to_f / total_val * 100).round(1) : nil

    # Subtriagem = IA classificou como MENOS urgente do que a equipe decidiu
    # (o erro clinicamente perigoso). Sobretriagem = MAIS urgente (lado seguro).
    setting = TriageSetting.current
    @undertriage_count = compared.count do |v|
      setting.urgency_weight_for(v.final_urgency_level) < setting.urgency_weight_for(v.ai_classification.urgency_level)
    end
    @overtriage_count = compared.count do |v|
      setting.urgency_weight_for(v.final_urgency_level) > setting.urgency_weight_for(v.ai_classification.urgency_level)
    end

    # ── Distribuição por urgência no período ──────────────────────────
    raw_urgency = QueueEntry.where(queued_at: @range, triage_session_id: sessions.select(:id))
                            .group(:urgency_level).count
    levels = TriageSetting.current.urgency_levels
    @urgency_counts = raw_urgency # legenda do gráfico
    @urgency_chart_data = {
      labels: levels.map { |l| l["label"] },
      values: levels.map { |l| raw_urgency[l["key"]] || 0 },
      colors: levels.map { |l| l["color"] }
    }

    # ── Tendência diária: o período escolhido (no mínimo 7 dias) ─────────
    trend_days = trend_start..@range.end.to_date
    finished_per_day = sessions.where(status: :completed, finished_at: trend_days.first.beginning_of_day..@range.end)
                               .pluck(:finished_at)
                               .group_by { |time| time.in_time_zone.to_date }
    @daily_trend_data = {
      labels: trend_days.map { |d| d.strftime("%d/%m") },
      values: trend_days.map { |d| finished_per_day[d]&.size || 0 }
    }
    @trend_label = trend_days.count > 1 ? "#{trend_days.first.strftime("%d/%m")} a #{trend_days.last.strftime("%d/%m")}" : ""

    # ── Atendimentos concluídos no período ────────────────────────────
    @recent = completed_sessions(sessions).limit(RECENT_LIMIT)
  end

  def export_csv
    sessions = completed_sessions(filtered_sessions)

    csv_data = CSV.generate(headers: true, col_sep: ";", encoding: "UTF-8") do |csv|
      csv << [
        "Data/Hora", "Paciente", "E-mail",
        "Urgência IA", "Urgência Final", "Decisão da Equipe", "Notas",
        "Validado por", "Check-in por", "Chamado por", "Finalizado por"
      ]

      sessions.find_each do |session|
        ai          = session.ai_classification
        validation  = ai&.triage_validation
        entry       = session.queue_entry
        final_level = validation&.final_urgency_level || ai&.urgency_level

        csv << [
          session.finished_at&.strftime("%d/%m/%Y %H:%M"),
          session.user.name,
          session.user.email,
          ai ? TriageSetting.current.urgency_label_for(ai.urgency_level) : "—",
          final_level ? TriageSetting.current.urgency_label_for(final_level) : "—",
          validation ? I18n.t("enums.triage_validation.decision.#{validation.decision}") : "—",
          validation&.notes.presence || "—",
          validation&.user&.name || "—",
          session.checked_in_at ? (session.checked_in_by&.name || "Próprio solicitante") : "—",
          entry&.called_by&.name || "—",
          entry&.finished_by&.name || "—"
        ]
      end
    end

    send_data "\xEF\xBB\xBF#{csv_data}",
              filename: "atendimentos_#{@range.begin.strftime("%Y%m%d")}_#{@range.end.strftime("%Y%m%d")}.csv",
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  private

  # Período: atalho (hoje/7/30 dias) ou datas escolhidas. Só uma data
  # preenchida = aquele dia específico. Colaborador: opcional.
  def load_filters
    @date_from = parse_date(params[:date_from])
    @date_to   = parse_date(params[:date_to])

    if @date_from || @date_to
      @date_from ||= @date_to
      @date_to   ||= @date_from
      @date_from, @date_to = @date_to, @date_from if @date_from > @date_to
      @date_from = [ @date_from, @date_to - MAX_RANGE_DAYS ].max
      @period = "custom"
      @range  = @date_from.in_time_zone.beginning_of_day..@date_to.in_time_zone.end_of_day
    else
      @period = params[:period].presence_in(PERIODS) || "today"
      @range  = period_range(@period)
    end
    @period_label = period_label

    @staff_options = User.where("colaborador = true OR specialist = true OR admin = true").order(:name)
    @staff_member  = @staff_options.find_by(id: params[:staff_id]) if params[:staff_id].present?
  end

  def filtered_sessions
    @staff_member ? TriageSession.with_staff_participation(@staff_member.id) : TriageSession.all
  end

  def completed_sessions(sessions)
    sessions
      .includes(:user, :checked_in_by,
                queue_entry: [ :called_by, :finished_by ],
                ai_classification: { triage_validation: :user })
      .where(status: :completed, finished_at: @range)
      .order(finished_at: :desc)
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end

  def period_range(period)
    case period
    when "today" then Time.current.beginning_of_day..Time.current.end_of_day
    when "week"  then 6.days.ago.beginning_of_day..Time.current.end_of_day
    when "month" then 29.days.ago.beginning_of_day..Time.current.end_of_day
    end
  end

  def period_label
    case @period
    when "today" then "Hoje, #{I18n.l(Date.current, format: :long)}"
    when "week"  then "Últimos 7 dias"
    when "month" then "Últimos 30 dias"
    else
      @date_from == @date_to ? I18n.l(@date_from, format: :long) :
        "#{@date_from.strftime("%d/%m/%Y")} a #{@date_to.strftime("%d/%m/%Y")}"
    end
  end

  def trend_start
    [ @range.begin.to_date, @range.end.to_date - 6 ].min
  end
end
