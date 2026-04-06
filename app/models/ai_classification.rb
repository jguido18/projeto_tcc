class AiClassification < ApplicationRecord
  belongs_to :triage_session
  has_one :triage_validation, dependent: :restrict_with_error

  validates :urgency_level, presence: true
  validates :summary, presence: true
  validates :ai_model, presence: true
  validates :generated_at, presence: true
  validates :identified_symptoms, presence: true
  validate :urgency_level_must_exist_in_settings

  def urgency_label
    TriageSetting.current.urgency_label_for(urgency_level)
  end

  def urgency_weight
    TriageSetting.current.urgency_weight_for(urgency_level)
  end

  def pending_validation?
    triage_validation.nil?
  end

  private

  def urgency_level_must_exist_in_settings
    return if urgency_level.blank?
    return if TriageSetting.current.urgency_keys.include?(urgency_level)

    errors.add(:urgency_level, "não está configurado no painel da IA")
  end
end
