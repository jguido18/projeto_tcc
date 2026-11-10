# Linha do tempo de um atendimento: o que aconteceu, quando e quem fez cada
# etapa (solicitante, IA ou membro da equipe). É montada a partir dos registros
# que já existem — nada é gravado à parte —, então mostra exatamente o que está
# no banco. Atendimentos anteriores ao registro de "quem chamou/finalizou"
# aparecem com o responsável "não registrado".
class AttendanceTimeline
  Event = Data.define(:at, :title, :actor, :detail, :kind) # kind: :patient | :ai | :staff | :system

  ROLE_LABELS = { specialist: "Especialista", colaborador: "Colaborador", admin: "Admin" }.freeze

  def initialize(triage_session)
    @session        = triage_session
    @classification = triage_session.ai_classification
    @validation     = @classification&.triage_validation
    @entry          = triage_session.queue_entry
  end

  def events
    list = [ started_event, classification_event, checkin_event, validation_event, *queue_events, closing_event ]
    list.compact.sort_by(&:at)
  end

  # "Fulano (Especialista)" — também usado no relatório.
  def self.staff_label(user)
    return "Não registrado" unless user

    role = ROLE_LABELS.find { |flag, _| user.public_send("#{flag}?") }&.last
    label = role ? "#{user.name} (#{role})" : user.name
    user.active? ? label : "#{label} — inativo"
  end

  private

  def patient_name
    @session.user.name
  end

  def staff_label(user) = self.class.staff_label(user)

  def urgency_label(level) = TriageSetting.current.urgency_label_for(level)

  def started_event
    Event.new(at: @session.started_at, title: "Triagem iniciada", actor: patient_name,
              detail: @session.initial_demand, kind: :patient)
  end

  def classification_event
    return unless @classification

    confidence = @classification.confidence_score ? " · confiança #{@classification.confidence_score.to_i}%" : ""
    Event.new(at: @classification.generated_at, title: "IA classificou a triagem",
              actor: "IA (#{@classification.ai_model})",
              detail: "#{urgency_label(@classification.urgency_level)}#{confidence}", kind: :ai)
  end

  def checkin_event
    return unless @session.checked_in_at

    by_staff = @session.checked_in_by.present?
    Event.new(at: @session.checked_in_at, title: "Check-in no local",
              actor: by_staff ? staff_label(@session.checked_in_by) : "#{patient_name} (código da TV)",
              detail: by_staff ? "Presença confirmada pela recepção" : nil,
              kind: by_staff ? :staff : :patient)
  end

  def validation_event
    return unless @validation

    title = @validation.user&.specialist? ? "Classificação avaliada pelo especialista" : "Classificação validada pela equipe"
    Event.new(at: @validation.validated_at, title: title, actor: staff_label(@validation.user),
              detail: validation_detail, kind: :staff)
  end

  def validation_detail
    ai_level    = urgency_label(@classification.urgency_level)
    final_level = urgency_label(@validation.final_urgency_level)

    text = case @validation.decision
    when "confirmed" then "Confirmou a classificação da IA (#{final_level})"
    when "adjusted"  then "Ajustou de #{ai_level} para #{final_level}"
    else "Rejeitou a classificação da IA"
    end
    @validation.notes.present? ? "#{text} — \"#{@validation.notes}\"" : text
  end

  def queue_events
    return [] unless @entry

    events = [
      Event.new(at: @entry.queued_at, title: "Entrou na fila", actor: nil,
                detail: "Senha #{@entry.ticket_number} · #{urgency_label(@entry.urgency_level)}", kind: :system)
    ]

    if @entry.called_at
      events << Event.new(at: @entry.called_at, title: "Paciente chamado",
                          actor: staff_label(@entry.called_by), detail: nil, kind: :staff)
    end

    if @entry.service_finished_at
      events << if @entry.left?
        Event.new(at: @entry.service_finished_at, title: "Saiu da fila", actor: patient_name,
                  detail: "Iniciou uma nova triagem", kind: :patient)
      else
        Event.new(at: @entry.service_finished_at, title: "Atendimento finalizado",
                  actor: staff_label(@entry.finished_by), detail: nil, kind: :staff)
      end
    end

    events
  end

  def closing_event
    if @session.cancelled? && @entry.nil?
      Event.new(at: @session.finished_at || @session.updated_at, title: "Triagem cancelada",
                actor: patient_name, detail: nil, kind: :patient)
    elsif @session.expired?
      Event.new(at: @session.updated_at, title: "Triagem expirada", actor: nil,
                detail: "Sem check-in no prazo", kind: :system)
    end
  end
end
