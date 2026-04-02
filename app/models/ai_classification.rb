class AiClassification < ApplicationRecord
  belongs_to :triage_session
  has_one :triage_validation, dependent: :restrict_with_error

  URGENCY_LEVELS = %w[red orange yellow green blue].freeze
  URGENCY_LABELS = {
    "red"    => "Emergência",
    "orange" => "Muito Urgente",
    "yellow" => "Urgente",
    "green"  => "Pouco Urgente",
    "blue"   => "Não Urgente"
  }.freeze
  URGENCY_WEIGHTS = {
    "red" => 1, "orange" => 2, "yellow" => 3, "green" => 4, "blue" => 5
  }.freeze

  enum :urgency_level, {
    red:    "red",
    orange: "orange",
    yellow: "yellow",
    green:  "green",
    blue:   "blue"
  }

  validates :urgency_level, presence: true
  validates :summary, presence: true
  validates :ai_model, presence: true
  validates :generated_at, presence: true
  validates :identified_symptoms, presence: true

  def urgency_label
    URGENCY_LABELS[urgency_level]
  end

  def urgency_weight
    URGENCY_WEIGHTS[urgency_level]
  end

  def pending_validation?
    triage_validation.nil?
  end
end
