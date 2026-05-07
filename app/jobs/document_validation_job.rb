class DocumentValidationJob < ApplicationJob
  queue_as :default

  def perform(triage_document_id)
    doc = TriageDocument.find_by(id: triage_document_id)
    return unless doc&.pending_doc?

    result = DocumentValidatorService.new(doc).validate

    # Broadcast validation result to the patient's queue channel
    # so the frontend can update the document validation badge in real time.
    session = doc.triage_session
    TriageChannel.broadcast_document_validation(session, doc, result)
  rescue => e
    Rails.logger.error("[DocumentValidationJob] id=#{triage_document_id} #{e.class}: #{e.message}")
  end
end
