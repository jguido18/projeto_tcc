setting = TriageSetting.current
setting.update!(
  purpose: "Triagem clínica geral",
  system_prompt: TriageSetting::DEFAULT_SYSTEM_PROMPT,
  urgency_levels: TriageSetting::DEFAULT_URGENCY_LEVELS
)

puts "Configuração global da IA de triagem atualizada."
