class QueueEntry < ApplicationRecord
  belongs_to :triage_session
  belongs_to :user
  belongs_to :establishment

  enum :urgency_level, {
    red:    "red",
    orange: "orange",
    yellow: "yellow",
    green:  "green",
    blue:   "blue"
  }

  enum :status, {
    waiting:       "waiting",
    called:        "called",
    in_attendance: "in_attendance",
    left:          "left",
    completed:     "completed"
  }

  validates :urgency_level, presence: true
  validates :urgency_weight, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :status, presence: true
  validates :queued_at, presence: true
  validates :ticket_number, presence: true, uniqueness: true

  before_validation :set_urgency_weight, if: -> { urgency_level.present? && urgency_weight.blank? }

  # Returns position in queue (1-based) calculated dynamically
  def queue_position
    QueueEntry
      .where(establishment: establishment, status: :waiting)
      .where(
        "urgency_weight < ? OR (urgency_weight = ? AND queued_at < ?)",
        urgency_weight, urgency_weight, queued_at
      )
      .count + 1
  end

  def urgency_label
    AiClassification::URGENCY_LABELS[urgency_level]
  end

  private

  def set_urgency_weight
    self.urgency_weight = AiClassification::URGENCY_WEIGHTS[urgency_level]
  end
end
