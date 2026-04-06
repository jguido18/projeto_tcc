class TvChannel < ApplicationCable::Channel
  # Canal público — não exige usuário autenticado.
  def subscribed
    stream_from "tv_global"
  end

  def unsubscribed
    stop_all_streams
  end

  # Chamado sempre que um paciente é chamado ou um atendimento é finalizado.
  # Envia a lista atual de pacientes chamados para a TV.
  def self.broadcast_update
    entries = QueueEntry
      .includes(triage_session: :user)
      .where(status: :called)
      .order(:urgency_weight, :called_at)
      .map do |entry|
        {
          id:             entry.id,
          ticket_number:  entry.ticket_number,
          patient_name:   entry.triage_session.user.name,
          urgency_level:  entry.urgency_level,
          urgency_label:  entry.urgency_label,
          urgency_color:  entry.urgency_color,
          called_at:      entry.called_at&.strftime("%H:%M")
        }
      end

    ActionCable.server.broadcast(
      "tv_global",
      { type: "queue_update", entries: entries }
    )
  end

  # Destaque imediato de chamada — enviado separadamente para o efeito visual na TV.
  def self.broadcast_call(queue_entry)
    ActionCable.server.broadcast(
      "tv_global",
      {
        type:           "new_call",
        ticket_number:  queue_entry.ticket_number,
        patient_name:   queue_entry.triage_session.user.name,
        urgency_level:  queue_entry.urgency_level,
        urgency_label:  queue_entry.urgency_label,
        urgency_color:  queue_entry.urgency_color
      }
    )
  end
end
