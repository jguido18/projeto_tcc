class Api::QueueController < Api::BaseController
  # GET /api/queue
  # Retorna a lista de pacientes aguardando na fila.
  # Usado pelo app Vue para exibir o painel de fila em tempo real.
  def index
    minutes_per_service = QueueEntry.average_service_minutes

    ordered = QueueEntry
      .includes(triage_session: :user)
      .where(status: :waiting)
      .ordered_for_queue

    entries = ordered.each_with_index.map do |entry, idx|
      position = idx + 1  # posição real na fila ordenada
      {
        id:               entry.id,
        urgency_level:    entry.urgency_level,
        urgency_label:    entry.urgency_label,
        urgency_color:    entry.urgency_color,
        queue_position:   position,
        ticket_number:    entry.ticket_number,
        name:             entry.triage_session.user.name,
        priority_tier:    entry.priority_tier,
        priority_labels:  entry.priority_reasons.map { |r| User::PRIORITY_REASON_LABELS[r.to_sym] },
        is_mine:          entry.triage_session.user_id == current_user.id,
        estimated_wait:   estimated_wait_for(position, minutes_per_service)
      }
    end

    render json: { entries: entries }
  end

  private

  def estimated_wait_for(position, minutes_per_service)
    [ (position - 1) * minutes_per_service, 0 ].max
  end
end
