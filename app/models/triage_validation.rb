class TriageValidation < ApplicationRecord
  belongs_to :ai_classification
  belongs_to :user  # the colaborador who validated

  enum :decision, {
    confirmed: "confirmed",
    adjusted:  "adjusted",
    rejected:  "rejected"
  }

  validates :decision, presence: true
  validates :final_urgency_level, presence: true
  validates :validated_at, presence: true
  validates :notes, presence: true, if: -> { adjusted? || rejected? }

  validate :validator_must_be_staff
  validate :final_urgency_level_must_exist_in_settings

  delegate :triage_session, to: :ai_classification

  private

  def validator_must_be_staff
    unless user&.staff?
      errors.add(:base, "Somente colaboradores ou especialistas podem validar uma triagem.")
    end
  end

  def final_urgency_level_must_exist_in_settings
    return if final_urgency_level.blank?
    return if TriageSetting.current.urgency_keys.include?(final_urgency_level)

    errors.add(:final_urgency_level, "não está configurado no painel da IA")
  end
end
