class Api::QueueController < Api::BaseController
  # GET /api/queue
  # Retorna a lista de pacientes aguardando na fila (nomes anonimizados).
  # Usado pelo app Vue para exibir o painel de fila em tempo real.
  def index
    ordered = QueueEntry
      .includes(triage_session: :user)
      .where(status: :waiting)
      .order(:urgency_weight, :queued_at)

    entries = ordered.each_with_index.map do |entry, idx|
      position = idx + 1  # posição real na fila ordenada
      {
        id:             entry.id,
        urgency_level:  entry.urgency_level,
        urgency_label:  entry.urgency_label,
        urgency_color:  entry.urgency_color,
        queue_position: position,
        masked_name:    mask_name(entry.triage_session.user.name),
        is_mine:        entry.triage_session.user_id == current_user.id,
        estimated_wait: estimated_wait_for(position)
      }
    end

    render json: { entries: entries }
  end

  private

  def mask_name(name)
    parts = name.to_s.split
    return name if parts.empty?
    first = parts.first
    last  = parts.length > 1 ? " #{parts.last.slice(0, 1)}***" : ""
    "#{first}#{last}"
  end

  # Cada atendimento dura ~15 min; quem está na posição 1 espera ~0 min.
  MINUTES_PER_SERVICE = 15

  def estimated_wait_for(position)
    [ (position - 1) * MINUTES_PER_SERVICE, 0 ].max
  end
end
