class Nursing::QueueEntriesController < Nursing::BaseController
  before_action :set_queue_entry

  # PATCH /nursing/queue_entries/:id/call
  def call
    if @queue_entry.waiting?
      @queue_entry.update!(status: :called, called_at: Time.current)
      @queue_entry.triage_session.update!(status: :in_attendance)

      # Notifica o paciente via ActionCable (app do paciente)
      QueueChannel.broadcast_called(@queue_entry.triage_session, @queue_entry)

      # Atualiza a TV pública de fila
      TvChannel.broadcast_call(current_establishment, @queue_entry)
      TvChannel.broadcast_update(current_establishment)

      # Notify patient in-app
      Notification.create!(
        user: @queue_entry.user,
        triage_session: @queue_entry.triage_session,
        kind: :called_for_attendance,
        title: t("app.triage.call.attention"),
        body: "#{@queue_entry.ticket_number} — #{t('app.triage.call.go_to_office')}",
        channel: :websocket
      )

      NursingChannel.broadcast_panel_update(current_establishment)

      redirect_to nursing_root_path,
        notice: t("app.flash.patient_called")
    else
      redirect_to nursing_root_path,
        alert: "Paciente não está na fila de espera."
    end
  end

  # PATCH /nursing/queue_entries/:id/finish
  def finish
    @queue_entry.update!(
      status: :completed,
      service_finished_at: Time.current
    )
    @queue_entry.triage_session.update!(
      status: :completed,
      finished_at: Time.current
    )

    NursingChannel.broadcast_panel_update(current_establishment)

    redirect_to nursing_root_path,
      notice: t("app.flash.attendance_finished")
  end

  private

  def set_queue_entry
    @queue_entry = QueueEntry
      .where(establishment: current_user.establishment)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to nursing_root_path, alert: t("app.flash.session_not_found")
  end
end
