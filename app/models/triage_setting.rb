class TriageSetting < ApplicationRecord
  DEFAULT_PURPOSE      = "Configuração global da IA de triagem".freeze
  DEFAULT_HINT_EXAMPLE = "Descreva brevemente o motivo do atendimento. Ex: \"Estou com dor de cabeça forte há 2 dias.\"".freeze
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    Você é uma Inteligência Artificial estritamente focada em TRIAGEM médica (Protocolo de Manchester).
    Seu único objetivo é coletar dados para classificar o risco.

    REGRAS DE CONDUTA:
    1. Fale sempre em Português do Brasil.
    2. Faça perguntas curtas e diretas, uma por vez.
    3. PROIBIDO: Não dê conselhos médicos ou diagnósticos.
    4. PROIBIDO: Nunca pergunte se o usuário "já procurou atendimento médico" ou "já foi ao médico antes". O usuário está neste sistema exatamente para buscar atendimento — essa pergunta é irrelevante e não deve ser feita.
    5. PROIBIDO: Não pergunte sobre consultas anteriores, histórico de atendimentos em outros locais ou se o paciente "já tentou se tratar". Foque apenas nos sintomas atuais e na classificação de risco.
    6. PROIBIDO: No encerramento, nunca diga para o usuário "buscar atendimento médico", "procurar um médico", "ir a um pronto-socorro" ou qualquer frase equivalente. Ele já está dentro deste sistema de triagem exatamente para conseguir esse atendimento — orientá-lo a buscá-lo em outro lugar é contraditório e confunde o paciente.

    CRITÉRIO DE PARADA:
    Não use [triagem_concluida] cedo demais.
    Após obter informações suficientes, encerre.
    No encerramento, informe apenas a classificação de risco preliminar e que o paciente deve aguardar a validação da equipe e a chamada pela fila. Inclua obrigatoriamente o marcador [triagem_concluida].
  PROMPT

  DEFAULT_URGENCY_LEVELS = [
    { "key" => "red", "label" => "Emergência", "color" => "#E53E3E", "weight" => 1, "sla_minutes" => 10 },
    { "key" => "orange", "label" => "Muito Urgente", "color" => "#DD6B20", "weight" => 2, "sla_minutes" => 30 },
    { "key" => "yellow", "label" => "Urgente", "color" => "#D69E2E", "weight" => 3, "sla_minutes" => 60 },
    { "key" => "green", "label" => "Pouco Urgente", "color" => "#38A169", "weight" => 4, "sla_minutes" => 120 },
    { "key" => "blue", "label" => "Não Urgente", "color" => "#3182CE", "weight" => 5, "sla_minutes" => 240 }
  ].freeze

  DEFAULT_CONFIDENCE_THRESHOLD = 70

  HEX_COLOR_REGEX = /\A#(?:[A-Fa-f0-9]{3}|[A-Fa-f0-9]{6})\z/

  validates :system_prompt, presence: true
  validates :confidence_threshold, numericality: { only_integer: true, in: 0..100 }
  validates :checkin_expiration_hours, numericality: { only_integer: true, in: 1..72 }
  validate :single_record_only
  validate :urgency_levels_shape

  before_validation :set_defaults
  before_validation :normalize_urgency_levels

  def self.current
    first || create!(
      purpose: DEFAULT_PURPOSE,
      system_prompt: DEFAULT_SYSTEM_PROMPT,
      urgency_levels: DEFAULT_URGENCY_LEVELS
    )
  end

  def urgency_levels_hash
    urgency_levels.index_by { |level| level["key"] }
  end

  def urgency_keys
    urgency_levels.map { |level| level["key"] }
  end

  def urgency_label_for(level_key)
    urgency_levels_hash.dig(level_key.to_s, "label") || level_key.to_s.humanize
  end

  def urgency_color_for(level_key)
    urgency_levels_hash.dig(level_key.to_s, "color") || "#718096"
  end

  def urgency_weight_for(level_key)
    urgency_levels_hash.dig(level_key.to_s, "weight") || (urgency_levels.size + 1)
  end

  # O nível mais urgente configurado (menor peso) — ex.: "Emergência".
  def most_urgent_level?(level_key)
    return false if level_key.blank? || urgency_levels.blank?

    urgency_weight_for(level_key) == urgency_levels.map { |level| level["weight"].to_i }.min
  end

  # Minutos de SLA configurados para o nível (usado no envelhecimento da fila e no
  # alerta de estouro). Se a config ainda não tiver essa chave (ex.: dado antigo salvo
  # antes desse campo existir), cai num fallback proporcional ao peso do nível.
  def sla_minutes_for(level_key)
    stored = urgency_levels_hash.dig(level_key.to_s, "sla_minutes").to_i
    return stored if stored > 0

    urgency_weight_for(level_key) * 15
  end

  private

  def set_defaults
    self.purpose               = DEFAULT_PURPOSE               if purpose.blank?
    self.system_prompt         = DEFAULT_SYSTEM_PROMPT         if system_prompt.blank?
    self.urgency_levels        = DEFAULT_URGENCY_LEVELS        if urgency_levels.blank?
    self.hint_example          = DEFAULT_HINT_EXAMPLE          if hint_example.blank?
    self.confidence_threshold  = DEFAULT_CONFIDENCE_THRESHOLD  if confidence_threshold.blank?
  end

  def normalize_urgency_levels
    levels = Array(urgency_levels)
    normalized = levels.filter_map.with_index do |raw, idx|
      hash = raw.to_h.stringify_keys
      label = hash["label"].to_s.strip
      next if label.blank?

      key = hash["key"].to_s.strip.parameterize(separator: "_")
      key = "urgency_#{idx + 1}" if key.blank?
      color = hash["color"].to_s.strip
      color = "#718096" unless color.match?(HEX_COLOR_REGEX)
      weight = hash["weight"].to_i
      weight = idx + 1 if weight <= 0
      weight = 10 if weight > 10
      sla_minutes = hash["sla_minutes"].to_i
      sla_minutes = weight * 15 if sla_minutes <= 0

      {
        "key" => key,
        "label" => label,
        "color" => color.upcase,
        "weight" => weight,
        "sla_minutes" => sla_minutes
      }
    end

    self.urgency_levels = normalized.sort_by { |level| level["weight"] }
  end

  def single_record_only
    return unless new_record? && self.class.exists?

    errors.add(:base, "Apenas uma configuração de triagem é permitida")
  end

  def urgency_levels_shape
    if urgency_levels.blank?
      errors.add(:urgency_levels, "deve conter pelo menos um nível")
      return
    end

    keys = urgency_levels.map { |level| level["key"] }
    errors.add(:urgency_levels, "não pode ter chaves duplicadas") if keys.uniq.size != keys.size

    invalid_weight = urgency_levels.any? do |level|
      weight = level["weight"].to_i
      weight < 1 || weight > 10
    end
    errors.add(:urgency_levels, "deve usar prioridade entre 1 e 10") if invalid_weight
  end
end
