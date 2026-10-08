class ExpirePendingCheckinsJob < ApplicationJob
  queue_as :default

  # Triagem feita (às vezes de casa) e a pessoa nunca apareceu: depois do prazo
  # configurado (TriageSetting#checkin_expiration_hours) a sessão expira, para
  # não acumular triagens "fantasma" e liberar o solicitante para uma nova.
  def perform
    hours = TriageSetting.current.checkin_expiration_hours
    expired = TriageSession
      .where(status: :awaiting_checkin)
      .where(finished_at: ...hours.hours.ago)

    count = 0
    expired.find_each do |session|
      session.update!(status: :expired)
      TriageChannel.broadcast_status(session, :expired)
      count += 1
    end

    ValidationPanelChannel.broadcast_update if count.positive?
  rescue => e
    Rails.logger.error("[ExpirePendingCheckinsJob] #{e.class}: #{e.message}")
  end
end
