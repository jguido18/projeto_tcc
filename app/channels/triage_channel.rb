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
        id: message.id,
        sender: message.sender,
        content: message.content,
        suggested_replies: Array(message.ai_raw_response&.dig("suggested_replies")).first(4),
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

  def self.broadcast_document_validation(triage_session, triage_document, result)
    ActionCable.server.broadcast(
      "triage_session_#{triage_session.id}",
      {
        type:              "document_validation",
        document_id:       triage_document.id,
        validation_status: triage_document.validation_status,
        document_type:     triage_document.document_type,
        document_label:    triage_document.document_type_label,
        summary:           result["summary"],
        confidence_score:  result["confidence_score"],
        extracted_name:    result.dig("extracted_data", "name"),
        issues_found:      result["issues_found"] || []
      }
    )
  end
end
