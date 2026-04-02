class QueueChannel < ApplicationCable::Channel
  def subscribed
    session = TriageSession.find_by(id: params[:session_id])
    if session && session.user == current_user
      stream_from "queue_session_#{session.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_queued(triage_session, queue_entry)
    ActionCable.server.broadcast(
      "queue_session_#{triage_session.id}",
      {
        type: "queued",
        ticket_number: queue_entry.ticket_number,
        urgency_level: queue_entry.urgency_level,
        urgency_label: queue_entry.urgency_label,
        position: queue_entry.queue_position
      }
    )
  end

  def self.broadcast_position_update(triage_session, queue_entry)
    ActionCable.server.broadcast(
      "queue_session_#{triage_session.id}",
      {
        type: "position_update",
        position: queue_entry.queue_position,
        status: queue_entry.status
      }
    )
  end

  def self.broadcast_called(triage_session, queue_entry)
    ActionCable.server.broadcast(
      "queue_session_#{triage_session.id}",
      {
        type: "called",
        ticket_number: queue_entry.ticket_number
      }
    )
  end
end
