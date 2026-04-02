class QueueEntryService
  def initialize(triage_session)
    @session = triage_session
    @validation = triage_session.ai_classification.triage_validation
  end

  # Creates the QueueEntry after the attendant validates the triage.
  # Returns the created QueueEntry.
  def enqueue
    urgency = @validation.final_urgency_level

    entry = QueueEntry.create!(
      triage_session: @session,
      user: @session.user,
      establishment: @session.establishment,
      urgency_level: urgency,
      urgency_weight: AiClassification::URGENCY_WEIGHTS[urgency],
      ticket_number: generate_ticket,
      status: :waiting,
      queued_at: Time.current
    )

    @session.update!(status: :in_queue)

    # Notify patient via ActionCable
    QueueChannel.broadcast_queued(@session, entry)

    # Create in-app notification
    Notification.create!(
      user: @session.user,
      triage_session: @session,
      kind: :triage_validated,
      title: "Triagem validada",
      body: "Sua triagem foi validada. Sua senha é #{entry.ticket_number}. Urgência: #{entry.urgency_label}.",
      channel: :websocket
    )

    entry
  end

  private

  # Generates a unique alphanumeric ticket (e.g. SYZ99G5JC)
  def generate_ticket
    loop do
      ticket = SecureRandom.alphanumeric(9).upcase
      break ticket unless QueueEntry.exists?(ticket_number: ticket)
    end
  end
end
