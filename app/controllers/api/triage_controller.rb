class Api::TriageController < Api::BaseController
  before_action :set_session, only: %i[status messages send_message finish restart]

  # GET /api/triage/status
  # Retorna o estado atual da triagem do paciente logado.
  def status
    if @triage_session.nil?
      render json: { status: "none" } and return
    end

    render json: session_json(@triage_session)
  end

  # POST /api/triage/start
  # Cria uma nova sessão de triagem.
  def start
    if current_user.triage_sessions.active.exists?
      render json: { error: "Você já possui uma triagem ativa." }, status: :unprocessable_entity
      return
    end

    demand = params[:initial_demand].presence || params[:chief_complaint].presence

    unless demand.present?
      render json: { error: "Informe o motivo inicial do atendimento." }, status: :unprocessable_entity
      return
    end

    @triage_session = TriageSession.create!(
      user: current_user,
      status: :in_triage,
      initial_demand: demand,
      started_at: Time.current
    )

    TriageService.new(@triage_session).process_message(demand)

    render json: session_json(@triage_session), status: :created
  end

  # GET /api/triage/messages
  # Retorna o histórico de mensagens da sessão ativa.
  def messages
    msgs = @triage_session.chat_messages.order(:sequence).map do |m|
      {
        id:        m.id,
        sender:    m.sender,
        content:   m.content,
        sent_at:   m.sent_at.iso8601,
        sequence:  m.sequence
      }
    end
    render json: { messages: msgs }
  end

  # POST /api/triage/message
  # Envia uma mensagem do paciente e retorna a resposta da IA.
  def send_message
    unless @triage_session.in_triage?
      render json: { error: "Triagem não está ativa." }, status: :unprocessable_entity
      return
    end

    unless params[:content].present?
      render json: { error: "Mensagem vazia." }, status: :unprocessable_entity
      return
    end

    result = TriageService.new(@triage_session).process_message(params[:content])

    render json: {
      finished: result[:finished],
      session:  session_json(@triage_session.reload)
    }
  end

  # POST /api/triage/finish
  # Permite ao solicitante encerrar a etapa de perguntas e enviar para validação.
  def finish
    unless @triage_session.in_triage?
      render json: { error: "Triagem não está ativa." }, status: :unprocessable_entity
      return
    end

    begin
      TriageService.new(@triage_session).finalize_triage
    rescue StandardError => e
      Rails.logger.error("[Api::TriageController#finish] Failed: #{e.class} - #{e.message}")
      render json: { error: "Não foi possível finalizar a triagem agora." }, status: :unprocessable_entity
      return
    end

    render json: {
      finished: true,
      session: session_json(@triage_session.reload)
    }
  end

  # POST /api/triage/restart
  # Encerra a sessão ativa para permitir uma nova triagem.
  def restart
    if @triage_session.nil?
      render json: { ok: true, status: "none" }
      return
    end

    ActiveRecord::Base.transaction do
      if (entry = @triage_session.queue_entry).present? && !entry.completed?
        entry.update!(status: :left, service_finished_at: Time.current)
      end

      @triage_session.update!(status: :cancelled, finished_at: Time.current)
    end

    ValidationPanelChannel.broadcast_update
    TvChannel.broadcast_update

    render json: { ok: true, status: "none" }
  end

  private

  def set_session
    @triage_session = current_user.triage_sessions
      .where.not(status: %w[completed cancelled])
      .order(created_at: :desc)
      .first
  end

  def session_json(session)
    entry = session.queue_entry
    ai    = session.ai_classification

    {
      id:              session.id,
      status:          session.status,
      name:            current_user.name,
      initial_demand:  session.initial_demand,
      started_at:      session.started_at.iso8601,
      queue_entry:     entry ? queue_entry_json(entry) : nil,
      ai_summary:      ai&.summary,
      urgency_level:   ai&.urgency_level || entry&.urgency_level,
      urgency_label:   TriageSetting.current.urgency_label_for(ai&.urgency_level || entry&.urgency_level),
      urgency_levels:  TriageSetting.current.urgency_levels
    }
  end

  def queue_entry_json(entry)
    {
      id:             entry.id,
      ticket_number:  entry.ticket_number,
      status:         entry.status,
      urgency_level:  entry.urgency_level,
      urgency_label:  entry.urgency_label,
      queue_position: entry.waiting? ? entry.queue_position : nil,
      queued_at:      entry.queued_at.iso8601
    }
  end
end
