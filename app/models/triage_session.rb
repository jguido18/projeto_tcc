class TriageSession < ApplicationRecord
  belongs_to :user
  belongs_to :establishment
  has_many :chat_messages, dependent: :destroy
  has_one :ai_classification, dependent: :destroy
  has_one :queue_entry, dependent: :restrict_with_error

  enum :status, {
    in_triage: "in_triage",
    awaiting_validation: "awaiting_validation",
    validated: "validated",
    in_queue: "in_queue",
    in_attendance: "in_attendance",
    completed: "completed",
    cancelled: "cancelled"
  }

  validates :status, presence: true
  validates :started_at, presence: true

  # A user can only have one active session at a time
  validate :no_active_session_for_user, on: :create

  scope :active, -> { where(status: [ :in_triage, :awaiting_validation, :validated, :in_queue, :in_attendance ]) }
  scope :for_establishment, ->(establishment) { where(establishment: establishment) }

  private

  def no_active_session_for_user
    active_statuses = %w[in_triage awaiting_validation validated in_queue in_attendance]
    if TriageSession.where(user: user, status: active_statuses).exists?
      errors.add(:base, "User already has an active triage session")
    end
  end
end
