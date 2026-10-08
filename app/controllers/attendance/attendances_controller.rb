class Attendance::AttendancesController < Attendance::BaseController
  before_action :set_queue_entry

  # GET /attendance/attendances/:id
  def show
    @session     = @queue_entry.triage_session
    @patient     = @session.user
    @ai          = @session.ai_classification
    @validation  = @ai&.triage_validation
    @messages    = @session.chat_messages
    @documents   = @session.triage_documents.with_attached_file.order(:created_at)

    # Triagem que entrou na fila sem validação da equipe: o especialista pode
    # confirmar/ajustar a classificação da IA (se o admin habilitou).
    @can_review_classification = TriageSetting.current.specialist_review_enabled? &&
                                 @ai.present? && @validation.nil?
    @urgency_levels = TriageSetting.current.urgency_levels if @can_review_classification
  end

  # PATCH /attendance/attendances/:id/finish
  def finish
    @queue_entry.update!(
      status: :completed,
      service_finished_at: Time.current
    )
    @queue_entry.triage_session.update!(
      status: :completed,
      finished_at: Time.current
    )

    # Atualiza painel de validação e TV pública
    ValidationPanelChannel.broadcast_update
    TvChannel.broadcast_update

    redirect_to attendance_root_path, notice: t("app.flash.attendance_finished")
  end

  # POST /attendance/attendances/:id/review_classification
  # O especialista confirma ou ajusta a classificação da IA de uma triagem que
  # não passou pela validação da equipe. Não muda a fila (o paciente já foi
  # chamado) — registra a avaliação, que alimenta o relatório de precisão da IA.
  def review_classification
    classification = @queue_entry.triage_session.ai_classification

    unless TriageSetting.current.specialist_review_enabled? && classification && classification.triage_validation.nil?
      redirect_to attendance_attendance_path(@queue_entry), alert: "Esta classificação não está disponível para avaliação."
      return
    end

    final_level = params.dig(:triage_validation, :final_urgency_level)
    validation = TriageValidation.new(
      ai_classification: classification,
      user: current_user,
      final_urgency_level: final_level,
      decision: final_level == classification.urgency_level ? :confirmed : :adjusted,
      notes: params.dig(:triage_validation, :notes),
      validated_at: Time.current
    )

    if validation.save
      redirect_to attendance_attendance_path(@queue_entry), notice: "Avaliação da classificação da IA registrada."
    else
      redirect_to attendance_attendance_path(@queue_entry), alert: validation.errors.full_messages.to_sentence
    end
  end

  private

  def set_queue_entry
    @queue_entry = QueueEntry
      .includes(triage_session: [ :user, { ai_classification: :triage_validation }, :chat_messages ])
      .where(status: [ :called, :completed ])
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to attendance_root_path, alert: t("app.flash.session_not_found")
  end
end
