class TriageValidation < ApplicationRecord
  belongs_to :ai_classification
  belongs_to :user  # the attendant who validated

  enum :decision, {
    confirmed: "confirmed",
    adjusted:  "adjusted",
    rejected:  "rejected"
  }

  enum :final_urgency_level, {
    red:    "red",
    orange: "orange",
    yellow: "yellow",
    green:  "green",
    blue:   "blue"
  }

  validates :decision, presence: true
  validates :final_urgency_level, presence: true
  validates :validated_at, presence: true
  validates :notes, presence: true, if: -> { adjusted? || rejected? }

  validate :validator_must_be_staff

  delegate :triage_session, to: :ai_classification

  private

  def validator_must_be_staff
    unless user&.staff?
      errors.add(:user, "must be an attendant or doctor to validate")
    end
  end
end
