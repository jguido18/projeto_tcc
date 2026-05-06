class TriageService
  def initialize(triage_session)
    @session = triage_session
    @ai = AiService.new(triage_session)
  end

  # Processes a patient message, optionally with an uploaded document.
  # uploaded_file: ActionDispatch::Http::UploadedFile or nil
  # Returns: { ai_message: ChatMessage, finished: Boolean, document: TriageDocument|nil, document_error: String|nil }
  def process_message(content, uploaded_file: nil)
    next_seq = (@session.chat_messages.maximum(:sequence) || 0) + 1

    triage_document = nil
    document_error  = nil
    document_context = nil

    if uploaded_file.present?
      triage_document, document_context, document_error = handle_document(uploaded_file)
    end

    # Persist patient message (display text only; document stored separately)
    display_content = document_error || content
    user_msg = @session.chat_messages.create!(
      sender:   :user,
      content:  display_content,
      sequence: next_seq,
      sent_at:  Time.current
    )

    triage_document&.update!(chat_message: user_msg)

    # Broadcast the user message immediately
    TriageChannel.broadcast_message(@session, user_msg)

    # Call AI (skip on document processing error to avoid confusing the AI)
    if document_error
      next_seq += 1
      ai_msg = @session.chat_messages.create!(
        sender:   :ai,
        content:  "Não consegui processar o arquivo enviado. #{document_error} Por favor, continue com a descrição do seu caso.",
        sequence: next_seq,
        sent_at:  Time.current
      )
      TriageChannel.broadcast_message(@session, ai_msg)
      return { ai_message: ai_msg, finished: false, document: triage_document, document_error: document_error }
    end

    begin
      ai_result = @ai.call(content, document_context: document_context)
    rescue StandardError => e
      Rails.logger.error("[TriageService] AI call failed: #{e.class} - #{e.message}")
      ai_result = {
        content:      "Desculpe, ocorreu um erro ao processar sua mensagem. Tente novamente em instantes.",
        raw_response: { error: e.message },
        finished:     false
      }
    end
    next_seq += 1

    ai_msg = @session.chat_messages.create!(
      sender:          :ai,
      content:         ai_result[:content],
      ai_raw_response: ai_result[:raw_response],
      sequence:        next_seq,
      sent_at:         Time.current
    )

    TriageChannel.broadcast_message(@session, ai_msg)

    finalize_triage if ai_result[:finished]

    { ai_message: ai_msg, finished: ai_result[:finished], document: triage_document, document_error: nil }
  end

  private

  # Creates TriageDocument, processes the file and runs validation.
  # Returns: [triage_document, document_context, error_message]
  def handle_document(uploaded_file)
    # Read raw bytes BEFORE attach — ActiveStorage consumes the IO stream during attach.
    raw_bytes = uploaded_file.read
    uploaded_file.rewind

    doc = TriageDocument.create!(
      triage_session:    @session,
      original_filename: uploaded_file.original_filename,
      content_type:      uploaded_file.content_type,
      validation_status: :pending
    )
    doc.file.attach(uploaded_file)

    result = DocumentProcessorService.new(raw_bytes, uploaded_file.content_type).process

    if result.type == :error
      doc.update!(validation_status: :skipped,
                  validation_result: { error: result.error })
      return [ doc, nil, result.error ]
    end

    # Run document validation asynchronously to not block the chat response.
    # We validate only images (vision API requirement).
    DocumentValidationJob.perform_later(doc.id) if doc.image?

    context = case result.type
              when :image then { type: :image, base64: result.base64, content_type: result.content_type }
              when :text  then { type: :text, text: result.text }
              end

    [ doc, context, nil ]
  rescue => e
    Rails.logger.error("[TriageService] handle_document failed: #{e.class} - #{e.message}")
    [ nil, nil, "Erro interno ao processar o documento." ]
  end

  public

  # Generates the AI classification and transitions session to awaiting_validation.
  def finalize_triage
    # Idempotent: if already classified, only ensures state transition and broadcasts.
    classification = @session.ai_classification

    if classification.nil?
      classification_data = @ai.classify

      classification = AiClassification.create!(
        triage_session: @session,
        urgency_level: classification_data["urgency_level"],
        protocol_reference: classification_data["protocol_reference"] || classification_data["manchester_code"],
        summary: classification_data["summary"],
        identified_symptoms: classification_data["identified_symptoms"] || [],
        ai_suggestion: classification_data["ai_suggestion"],
        classification_reasoning: classification_data["classification_reasoning"] || classification_data["clinical_reasoning"],
        routing_suggestion: classification_data["routing_suggestion"] || classification_data["specialty_suggestion"],
        confidence_score: classification_data["confidence_score"],
        ai_model: @ai.model_identifier,
        generated_at: Time.current
      )
    end

    if @session.in_triage?
      @session.update!(status: :awaiting_validation, finished_at: Time.current)
      TriageChannel.broadcast_status(@session, :awaiting_validation)
    end

    classification
  end
end
