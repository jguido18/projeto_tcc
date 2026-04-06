class Api::TriageController < Api::BaseController
  before_action :set_session, only: %i[status messages send_message]

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

    unless params[:chief_complaint].present?
      render json: { error: "Informe sua queixa principal." }, status: :unprocessable_entity
      return
    end

    @triage_session = TriageSession.create!(
      user: current_user,
      establishment: current_user.establishment,
      status: :in_triage,
      chief_complaint: params[:chief_complaint],
      started_at: Time.current
    )

    TriageService.new(@triage_session).process_message(params[:chief_complaint])

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
      chief_complaint: session.chief_complaint,
      started_at:      session.started_at.iso8601,
      queue_entry:     entry ? queue_entry_json(entry) : nil,
      ai_summary:      ai&.summary,
      urgency_level:   ai&.urgency_level || entry&.urgency_level,
      urgency_label:   AiClassification::URGENCY_LABELS[ai&.urgency_level || entry&.urgency_level]
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
