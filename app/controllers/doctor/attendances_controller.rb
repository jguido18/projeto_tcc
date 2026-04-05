class Doctor::AttendancesController < Doctor::BaseController
  before_action :set_queue_entry

  # GET /doctor/attendances/:id
  def show
    @session     = @queue_entry.triage_session
    @patient     = @session.user
    @ai          = @session.ai_classification
    @validation  = @ai&.triage_validation
    @messages    = @session.chat_messages
  end

  # PATCH /doctor/attendances/:id/finish
  def finish
    @queue_entry.update!(
      status: :completed,
      service_finished_at: Time.current
    )
    @queue_entry.triage_session.update!(
      status: :completed,
      finished_at: Time.current
    )

    # Atualiza painel da enfermagem e TV pública
    NursingChannel.broadcast_panel_update(current_establishment)
    TvChannel.broadcast_update(current_establishment)

    redirect_to doctor_root_path, notice: t("app.flash.attendance_finished")
  end

  private

  def set_queue_entry
    @queue_entry = QueueEntry
      .includes(triage_session: [ :user, { ai_classification: :triage_validation }, :chat_messages ])
      .where(establishment: current_establishment, status: :called)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to doctor_root_path, alert: t("app.flash.session_not_found")
  end
end
