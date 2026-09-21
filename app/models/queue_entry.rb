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

  # Ordenação oficial da fila: urgência clínica > prioridade legal (idoso/PCD/...) > ordem de chegada
  scope :ordered_for_queue, -> { order(:urgency_weight).order(priority_tier: :desc).order(:queued_at) }

  # Cada atendimento dura, em média, isso — usado como fallback quando não há histórico
  DEFAULT_SERVICE_MINUTES = 15
  RECENT_SERVICE_SAMPLE_SIZE = 50

  # Média (em minutos) dos atendimentos concluídos recentemente, do momento em
  # que o paciente foi chamado até o encerramento. Cai no valor padrão quando
  # ainda não há histórico suficiente.
  def self.average_service_minutes
    durations = completed
      .where.not(called_at: nil)
      .where.not(service_finished_at: nil)
      .order(service_finished_at: :desc)
      .limit(RECENT_SERVICE_SAMPLE_SIZE)
      .pluck(:called_at, :service_finished_at)
      .map { |called_at, finished_at| (finished_at - called_at) / 60.0 }

    return DEFAULT_SERVICE_MINUTES if durations.empty?

    (durations.sum / durations.size).round
  end

  # Returns position in queue (1-based) calculated dynamically
  def queue_position
    QueueEntry
      .where(status: :waiting)
      .where(
        "urgency_weight < :uw
         OR (urgency_weight = :uw AND priority_tier > :tier)
         OR (urgency_weight = :uw AND priority_tier = :tier AND queued_at < :qat)",
        uw: urgency_weight, tier: priority_tier, qat: queued_at
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
