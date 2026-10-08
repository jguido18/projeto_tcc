class QueueEntryService
  def initialize(triage_session)
    @session = triage_session
    @classification = triage_session.ai_classification
    @validation = @classification.triage_validation
  end

  # Creates the QueueEntry after the triage is concluded — either validated by
  # a colaborador or, when TriageSetting#require_staff_validation is off,
  # straight from the AI classification. Returns the created QueueEntry.
  def enqueue
    urgency = @validation&.final_urgency_level || @classification.urgency_level

    patient = @session.user

    entry = QueueEntry.create!(
      triage_session: @session,
      user: patient,
      urgency_level: urgency,
      urgency_weight: TriageSetting.current.urgency_weight_for(urgency),
      ticket_number: generate_ticket,
      status: :waiting,
      queued_at: Time.current,
      priority_tier: patient.priority_tier,
      priority_reasons: patient.priority_reasons.map(&:to_s)
    )

    @session.update!(status: :in_queue)

    # Notify patient via ActionCable
    QueueChannel.broadcast_queued(@session, entry)

    # Create in-app notification
    Notification.create!(
      user: @session.user,
      triage_session: @session,
      kind: :triage_validated,
      title: @validation ? "Triagem validada" : "Triagem concluída",
      body: "Sua triagem foi #{@validation ? "validada" : "concluída"}. Sua senha é #{entry.ticket_number}. Urgência: #{entry.urgency_label}.",
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
