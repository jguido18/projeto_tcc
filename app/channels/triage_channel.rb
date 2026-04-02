class TriageChannel < ApplicationCable::Channel
  def subscribed
    session = TriageSession.find_by(id: params[:session_id])
    if session && session.user == current_user
      stream_from "triage_session_#{session.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Class-level helpers used by TriageService to broadcast events
  def self.broadcast_message(triage_session, message)
    ActionCable.server.broadcast(
      "triage_session_#{triage_session.id}",
      {
        type: "message",
        sender: message.sender,
        content: message.content,
        sequence: message.sequence,
        sent_at: message.sent_at.iso8601
      }
    )
  end

  def self.broadcast_status(triage_session, status)
    ActionCable.server.broadcast(
      "triage_session_#{triage_session.id}",
      { type: "status_change", status: status }
    )
  end
end
