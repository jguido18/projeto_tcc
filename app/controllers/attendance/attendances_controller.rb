class Attendance::AttendancesController < Attendance::BaseController
  before_action :set_queue_entry

  # GET /attendance/attendances/:id
  def show
    @session     = @queue_entry.triage_session
    @patient     = @session.user
    @ai          = @session.ai_classification
    @validation  = @ai&.triage_validation
    @messages    = @session.chat_messages
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

  private

  def set_queue_entry
    @queue_entry = QueueEntry
      .includes(triage_session: [ :user, { ai_classification: :triage_validation }, :chat_messages ])
      .where(status: :called)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to attendance_root_path, alert: t("app.flash.session_not_found")
  end
end
