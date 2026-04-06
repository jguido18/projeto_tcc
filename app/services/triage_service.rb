class TriageService
  def initialize(triage_session)
    @session = triage_session
    @ai = AiService.new(triage_session)
  end

  # Processes a patient message: persists it, calls the AI, persists the AI reply.
  # Broadcasts both messages via ActionCable.
  # Returns: { ai_message: ChatMessage, finished: Boolean }
  def process_message(content)
    next_seq = (@session.chat_messages.maximum(:sequence) || 0) + 1

    # Persist patient message
    user_msg = @session.chat_messages.create!(
      sender: :user,
      content: content,
      sequence: next_seq,
      sent_at: Time.current
    )

    # Call AI
    begin
      ai_result = @ai.call(content)
    rescue StandardError => e
      Rails.logger.error("[TriageService] AI call failed: #{e.class} - #{e.message}")
      ai_result = {
        content: "Desculpe, ocorreu um erro ao processar sua mensagem. Tente novamente em instantes.",
        raw_response: { error: e.message },
        finished: false
      }
    end
    next_seq += 1

    # Persist AI reply
    ai_msg = @session.chat_messages.create!(
      sender: :ai,
      content: ai_result[:content],
      ai_raw_response: ai_result[:raw_response],
      sequence: next_seq,
      sent_at: Time.current
    )

    # Broadcast messages to the patient's cable channel
    TriageChannel.broadcast_message(@session, user_msg)
    TriageChannel.broadcast_message(@session, ai_msg)

    if ai_result[:finished]
      finalize_triage
    end

    { ai_message: ai_msg, finished: ai_result[:finished] }
  end

  # Generates the AI classification and transitions session to awaiting_validation.
  def finalize_triage
    classification_data = @ai.classify

    AiClassification.create!(
      triage_session: @session,
      urgency_level: classification_data["urgency_level"],
      manchester_code: classification_data["manchester_code"],
      summary: classification_data["summary"],
      identified_symptoms: classification_data["identified_symptoms"] || [],
      ai_suggestion: classification_data["ai_suggestion"],
      clinical_reasoning: classification_data["clinical_reasoning"],
      specialty_suggestion: classification_data["specialty_suggestion"],
      confidence_score: classification_data["confidence_score"],
      ai_model: AiService::MODEL,
      generated_at: Time.current
    )

    @session.update!(status: :awaiting_validation, finished_at: Time.current)

    TriageChannel.broadcast_status(@session, :awaiting_validation)
  end
end
