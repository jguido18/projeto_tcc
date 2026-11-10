class TriageSession < ApplicationRecord
  belongs_to :user
  # Recepção que confirmou a presença (nil = o próprio paciente pelo app)
  belongs_to :checked_in_by, class_name: "User", optional: true
  has_many :chat_messages, dependent: :destroy
  has_many :triage_documents, dependent: :destroy
  has_one :ai_classification, dependent: :destroy
  has_one :queue_entry, dependent: :restrict_with_error

  enum :status, {
    in_triage: "in_triage",
    awaiting_checkin: "awaiting_checkin",
    awaiting_validation: "awaiting_validation",
    validated: "validated",
    in_queue: "in_queue",
    in_attendance: "in_attendance",
    completed: "completed",
    cancelled: "cancelled",
    expired: "expired" # triagem feita, mas sem check-in no prazo
  }

  validates :status, presence: true
  validates :started_at, presence: true

  # A user can only have one active session at a time
  validate :no_active_session_for_user, on: :create

  ACTIVE_STATUSES = %w[in_triage awaiting_checkin awaiting_validation validated in_queue in_attendance].freeze

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  # Atendimentos em que o membro da equipe participou de alguma etapa:
  # validou/avaliou, fez check-in pela recepção, chamou ou finalizou.
  scope :with_staff_participation, ->(user_id) {
    left_joins(:queue_entry, ai_classification: :triage_validation)
      .where("triage_sessions.checked_in_by_id = :id OR queue_entries.called_by_id = :id " \
             "OR queue_entries.finished_by_id = :id OR triage_validations.user_id = :id", id: user_id)
  }

  # Membros da equipe que participaram deste atendimento (sem repetição).
  def staff_involved
    [
      ai_classification&.triage_validation&.user,
      checked_in_by,
      queue_entry&.called_by,
      queue_entry&.finished_by
    ].compact.uniq
  end

  # Até quando quem triou (de casa) pode fazer o check-in no local antes da
  # triagem expirar — ver TriageSetting#checkin_expiration_hours.
  def checkin_deadline
    return nil unless awaiting_checkin? && finished_at

    finished_at + TriageSetting.current.checkin_expiration_hours.hours
  end

  private

  def no_active_session_for_user
    if TriageSession.where(user: user, status: ACTIVE_STATUSES).exists?
      errors.add(:base, "Você já possui uma triagem em andamento.")
    end
  end
end
