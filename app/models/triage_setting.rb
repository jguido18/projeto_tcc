class TriageSetting < ApplicationRecord
  DEFAULT_PURPOSE      = "Configuração global da IA de triagem".freeze
  DEFAULT_HINT_EXAMPLE = "Descreva brevemente o motivo do atendimento. Ex: \"Estou com dor de cabeça forte há 2 dias.\"".freeze
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    Você é um assistente de triagem do sistema TriagemAI.
    Seu papel é coletar informações essenciais com linguagem empática e objetiva.

    Fluxo da triagem:
    1. Cumprimente e confirme a queixa principal.
    2. Explore início, duração e intensidade dos sintomas.
    3. Pergunte sintomas associados relevantes para o contexto.
    4. Pergunte alergias, medicamentos em uso e doenças prévias.
    5. Conclua quando houver informações suficientes.

    Regras:
    - Faça uma pergunta por vez.
    - Use linguagem simples.
    - Ao finalizar, inclua obrigatoriamente o marcador [triagem_concluida].
    - Não use [triagem_concluida] cedo demais.
  PROMPT

  DEFAULT_URGENCY_LEVELS = [
    { "key" => "red", "label" => "Emergência", "color" => "#E53E3E", "weight" => 1 },
    { "key" => "orange", "label" => "Muito Urgente", "color" => "#DD6B20", "weight" => 2 },
    { "key" => "yellow", "label" => "Urgente", "color" => "#D69E2E", "weight" => 3 },
    { "key" => "green", "label" => "Pouco Urgente", "color" => "#38A169", "weight" => 4 },
    { "key" => "blue", "label" => "Não Urgente", "color" => "#3182CE", "weight" => 5 }
  ].freeze

  HEX_COLOR_REGEX = /\A#(?:[A-Fa-f0-9]{3}|[A-Fa-f0-9]{6})\z/

  validates :system_prompt, presence: true
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

  private

  def set_defaults
    self.purpose       = DEFAULT_PURPOSE      if purpose.blank?
    self.system_prompt = DEFAULT_SYSTEM_PROMPT if system_prompt.blank?
    self.urgency_levels = DEFAULT_URGENCY_LEVELS if urgency_levels.blank?
    self.hint_example  = DEFAULT_HINT_EXAMPLE  if hint_example.blank?
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

      {
        "key" => key,
        "label" => label,
        "color" => color.upcase,
        "weight" => weight
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
