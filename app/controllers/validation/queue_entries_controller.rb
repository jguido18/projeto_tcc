class Validation::QueueEntriesController < Validation::BaseController
  before_action :set_queue_entry

  # PATCH /validation/queue_entries/:id/call
  def call
    if @queue_entry.waiting?
      @queue_entry.update!(status: :called, called_at: Time.current)
      @queue_entry.triage_session.update!(status: :in_attendance)

      # Notifica o solicitante via ActionCable (app do solicitante)
      QueueChannel.broadcast_called(@queue_entry.triage_session, @queue_entry)

      # Atualiza a TV pública de fila
      TvChannel.broadcast_call(@queue_entry)
      TvChannel.broadcast_update

      # Notify patient in-app
      Notification.create!(
        user: @queue_entry.user,
        triage_session: @queue_entry.triage_session,
        kind: :called_for_attendance,
        title: t("app.triage.call.attention"),
        body: "#{@queue_entry.ticket_number} — #{t('app.triage.call.go_to_office')}",
        channel: :websocket
      )

      # Notify patient via SMS, se ele optou por isso no perfil e tem telefone
      notify_via_sms

      ValidationPanelChannel.broadcast_update

      redirect_to validation_root_path,
        notice: t("app.flash.patient_called")
    else
      redirect_to validation_root_path,
        alert: "Atendimento não está na fila de espera."
    end
  end

  # PATCH /validation/queue_entries/:id/finish
  def finish
    @queue_entry.update!(
      status: :completed,
      service_finished_at: Time.current
    )
    @queue_entry.triage_session.update!(
      status: :completed,
      finished_at: Time.current
    )

    ValidationPanelChannel.broadcast_update

    redirect_to validation_root_path,
      notice: t("app.flash.attendance_finished")
  end

  private

  def notify_via_sms
    patient = @queue_entry.user
    return unless patient.sms_notifications_enabled? && patient.phone.present?

    sms_notification = Notification.create!(
      user: patient,
      triage_session: @queue_entry.triage_session,
      kind: :called_for_attendance,
      title: t("app.triage.call.attention"),
      body: "#{@queue_entry.ticket_number} — #{t('app.triage.call.go_to_office')}",
      channel: :sms
    )

    NotificationDeliveryJob.perform_later(sms_notification.id)
  end

  def set_queue_entry
    @queue_entry = QueueEntry
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to validation_root_path, alert: t("app.flash.session_not_found")
  end
end
