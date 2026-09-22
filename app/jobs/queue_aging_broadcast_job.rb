class QueueAgingBroadcastJob < ApplicationJob
  queue_as :default

  # Roda periodicamente (config/recurring.yml) só para "empurrar" atualizações em
  # tempo real. A ordenação em si (com o envelhecimento de prioridade) é sempre
  # recalculada na hora, a partir de QueueEntry#effective_urgency_weight — este job
  # não persiste nada, apenas avisa quem está com a tela aberta para recarregar.
  def perform
    return unless QueueEntry.waiting.exists?

    # Painel do colaborador: recarrega o turbo-frame com a fila já reordenada.
    ValidationPanelChannel.broadcast_update

    # Cada paciente aguardando: recalcula a própria posição/tempo estimado.
    QueueEntry.waiting.includes(:triage_session).find_each do |entry|
      QueueChannel.broadcast_position_update(entry.triage_session, entry)
    end
  rescue => e
    Rails.logger.error("[QueueAgingBroadcastJob] #{e.class}: #{e.message}")
  end
end
