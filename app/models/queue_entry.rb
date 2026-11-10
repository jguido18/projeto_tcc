class QueueEntry < ApplicationRecord
  belongs_to :triage_session
  belongs_to :user
  # Membro da equipe que chamou o paciente / que finalizou o atendimento
  belongs_to :called_by, class_name: "User", optional: true
  belongs_to :finished_by, class_name: "User", optional: true

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

  # Cada atendimento dura, em média, isso — usado como fallback quando não há histórico
  DEFAULT_SERVICE_MINUTES = 15
  RECENT_SERVICE_SAMPLE_SIZE = 50

  # Piso mínimo pro tempo médio exibido — protege a estimativa contra
  # atendimentos de teste/demonstração (chamar e finalizar em segundos), que
  # puxariam a média real pra baixo de forma irreal para o paciente.
  MIN_SERVICE_MINUTES = 5

  # Peso mínimo que o envelhecimento pode atingir (1 = nível mais urgente configurado).
  # O envelhecimento nunca "ultrapassa" um paciente que é vermelho de verdade — no
  # máximo empata com ele.
  MIN_EFFECTIVE_WEIGHT = 1

  # Ordenação oficial da fila, com envelhecimento dinâmico de prioridade: urgência
  # clínica efetiva (já considerando o tempo de espera) > urgência clínica original
  # > prioridade legal (idoso/PCD/...) > ordem de chegada. A urgência original como
  # desempate garante que quem envelheceu até empatar com um nível mais grave fica
  # atrás de quem é desse nível de verdade (ex.: um verde parado há horas empata com
  # o vermelho, mas nunca passa na frente dele). `relation` já deve vir filtrado por
  # status: :waiting (normalmente via QueueEntry.waiting) e com os includes que o
  # chamador precisar — a ordenação em si é feita em Ruby, não em SQL, porque a fila
  # de um atendimento real é pequena (dezenas, não milhares de pessoas) e assim a
  # fórmula de envelhecimento fica simples de ler e de testar.
  def self.waiting_ordered_with_aging(relation = waiting)
    now = Time.current
    relation.to_a.sort_by { |entry| [ entry.effective_urgency_weight(at: now), entry.urgency_weight, -entry.priority_tier, entry.queued_at ] }
  end

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

    [ (durations.sum / durations.size).round, MIN_SERVICE_MINUTES ].max
  end

  # Returns position in queue (1-based) calculated dynamically, já considerando o
  # envelhecimento de prioridade (ver .waiting_ordered_with_aging).
  def queue_position
    return nil unless waiting?

    self.class.waiting_ordered_with_aging.index(self).to_i + 1
  end

  # Minutos configurados de SLA para o nível de urgência desta entrada.
  def sla_minutes
    TriageSetting.current.sla_minutes_for(urgency_level)
  end

  # Minutos que o paciente já está esperando desde que entrou na fila.
  def waiting_minutes(at: Time.current)
    (at - queued_at) / 60.0
  end

  # Estourou o SLA do próprio nível de urgência sem ser chamado ainda?
  def sla_breached?(at: Time.current)
    waiting? && waiting_minutes(at: at) > sla_minutes
  end

  # Peso de urgência "efetivo" para fins de ordenação: a cada janela cheia de SLA
  # estourada sem atendimento, o peso sobe um nível (número menor = mais urgente),
  # até no máximo empatar com o nível mais urgente configurado. É uma técnica
  # clássica de "aging" de escalonamento aplicada à fila, para evitar que alguém de
  # baixa urgência espere indefinidamente enquanto casos mais graves continuam
  # chegando — sem nunca alterar a classificação clínica registrada.
  def effective_urgency_weight(at: Time.current)
    return urgency_weight unless waiting?

    aging_steps = (waiting_minutes(at: at) / sla_minutes).floor
    [ urgency_weight - aging_steps, MIN_EFFECTIVE_WEIGHT ].max
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
