class NotificationDeliveryJob < ApplicationJob
  queue_as :default

  # Entrega assíncrona de uma Notification por um canal externo (hoje só SMS),
  # para não travar a ação do colaborador esperando a resposta da API do provedor.
  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification

    case notification.channel
    when "sms"
      SmsNotifierService.new(notification).deliver
    end
  rescue => e
    Rails.logger.error("[NotificationDeliveryJob] notification_id=#{notification_id} #{e.class}: #{e.message}")
  end
end
