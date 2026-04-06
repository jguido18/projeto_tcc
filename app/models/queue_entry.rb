class QueueEntry < ApplicationRecord
  belongs_to :triage_session
  belongs_to :user

  enum :status, {
    waiting:       "waiting",
    called:        "called",
    in_attendance: "in_attendance",
    left:          "left",
    completed:     "completed"
  }

  validates :urgency_level, presence: true
  validates :urgency_weight, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true
  validates :queued_at, presence: true
  validates :ticket_number, presence: true, uniqueness: true
  validate :urgency_level_must_exist_in_settings

  before_validation :set_urgency_weight, if: -> { urgency_level.present? && urgency_weight.blank? }

  # Returns position in queue (1-based) calculated dynamically
  def queue_position
    QueueEntry
      .where(status: :waiting)
      .where(
        "urgency_weight < ? OR (urgency_weight = ? AND queued_at < ?)",
        urgency_weight, urgency_weight, queued_at
      )
      .count + 1
  end

  def urgency_label
    TriageSetting.current.urgency_label_for(urgency_level)
  end

  def urgency_color
    TriageSetting.current.urgency_color_for(urgency_level)
  end

  private

  def set_urgency_weight
    self.urgency_weight = TriageSetting.current.urgency_weight_for(urgency_level)
  end

  def urgency_level_must_exist_in_settings
    return if urgency_level.blank?
    return if TriageSetting.current.urgency_keys.include?(urgency_level)

    errors.add(:urgency_level, "não está configurado no painel da IA")
  end
end
