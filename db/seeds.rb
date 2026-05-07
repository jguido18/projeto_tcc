require "faker"
Faker::Config.locale = "en"

# ── Configuração global da IA ─────────────────────────────────────────────────
setting = TriageSetting.current
setting.update!(
  purpose: "Triagem clínica geral",
  system_prompt: TriageSetting::DEFAULT_SYSTEM_PROMPT,
  urgency_levels: TriageSetting::DEFAULT_URGENCY_LEVELS
)
puts "✓ Configuração da IA atualizada."

# ── Admin ─────────────────────────────────────────────────────────────────────
# Usa o primeiro admin existente ou cria um novo com email exclusivo
admin = User.find_by(admin: true) || User.new
if admin.new_record?
  admin.email       = "admin@admin.com"
  admin.name        = "Administrador"
  admin.password    = "123456789"
  admin.admin       = true
  admin.colaborador = true
  admin.job_title   = "manager"
  admin.active      = true
  admin.save!
end
puts "✓ Admin: #{admin.email}"

# ── Colaboradores (validação) ─────────────────────────────────────────────────
colaborador_titles = %w[nurse receptionist manager]

15.times do |i|
  email = "colaborador#{i + 1}@triagemAI.com"
  User.find_or_create_by!(email: email) do |u|
    u.name        = Faker::Name.name
    u.password    = "123456"
    u.colaborador = true
    u.job_title   = colaborador_titles.sample
    u.active      = [ true, true, true, false ].sample
  end
  print "."
end
puts "\n✓ 15 colaboradores criados."

# ── Especialistas (atendimento) ───────────────────────────────────────────────
12.times do |i|
  email = "especialista#{i + 1}@triagemAI.com"
  User.find_or_create_by!(email: email) do |u|
    u.name       = Faker::Name.name
    u.password   = "123456"
    u.specialist = true
    u.job_title  = "specialist"
    u.active     = [ true, true, true, false ].sample
  end
  print "."
end
puts "\n✓ 12 especialistas criados."

  email = "jguido@teste.com"
  User.find_or_create_by!(email: email) do |u|
    u.name       = "José Torrezan"
    u.password   = "123456"
    u.cpf        = Faker::Number.number(digits: 11).to_s
    u.birth_date = Faker::Date.birthday(min_age: 18, max_age: 80)
    u.phone      = Faker::PhoneNumber.cell_phone

# ── Pacientes (usuários comuns) ───────────────────────────────────────────────
30.times do |i|
  email = "paciente#{i + 1}@email.com"
  User.find_or_create_by!(email: email) do |u|
    u.name       = Faker::Name.name
    u.password   = "123456"
    u.cpf        = Faker::Number.number(digits: 11).to_s
    u.birth_date = Faker::Date.birthday(min_age: 18, max_age: 80)
    u.phone      = Faker::PhoneNumber.cell_phone
  end
  print "."
end
puts "\n✓ 30 pacientes criados."

# ── 15 pacientes na fila (para testes) ───────────────────────────────────────
DEMANDS = [
  "Estou com dor de cabeça intensa há 2 dias",
  "Sinto dor no peito ao respirar fundo",
  "Tenho febre alta desde ontem à noite",
  "Torci o tornozelo e não consigo andar",
  "Estou com tontura e náusea constante",
  "Minha pressão arterial está muito alta",
  "Sinto dor abdominal forte no lado direito",
  "Tenho falta de ar ao fazer esforço",
  "Machucei o braço e pode estar quebrado",
  "Estou com alergia forte, urticária no corpo todo",
  "Sinto dormência no lado esquerdo do rosto",
  "Tive convulsão há cerca de uma hora",
  "Criança com vômito e diarreia há 24 horas",
  "Corte profundo na mão que não para de sangrar",
  "Dor lombar intensa que irradia para a perna"
].freeze

URGENCY_LEVELS = %w[red orange orange yellow yellow yellow green green green blue].freeze

AI_SUMMARIES = [
  "Paciente relata cefaleia intensa bilateral há 48h, sem melhora com analgésicos comuns.",
  "Dor torácica pleurítica, piora à inspiração, sem histórico cardíaco conhecido.",
  "Síndrome febril aguda com temperatura acima de 38.5°C, iniciada ontem.",
  "Trauma em tornozelo direito após queda, edema e impotência funcional.",
  "Síndrome vertiginosa associada a náuseas, sem perda de consciência.",
  "Hipertensão arterial descompensada, PA referida acima de 180/110 mmHg.",
  "Dor abdominal aguda em fossa ilíaca direita, sinal de McBurney positivo suspeito.",
  "Dispneia aos esforços progressiva, sem histórico de asma ou DPOC.",
  "Trauma em membro superior com deformidade, suspeita de fratura.",
  "Reação alérgica cutânea difusa com urticária generalizada, sem angioedema.",
  "Parestesia hemifacial esquerda de início súbito, sem déficit motor.",
  "Crise convulsiva tônico-clônica generalizada, duração de 2 min, resolvida espontaneamente.",
  "Gastroenterite aguda pediátrica com risco de desidratação leve a moderada.",
  "Laceração em mão dominante com sangramento ativo, necessidade de sutura.",
  "Lombalgia aguda irradiada (L4-S5), provável compressão radicular."
].freeze

colaborador_for_validation = User.find_by(colaborador: true, active: true) || User.find_by(admin: true)

15.times do |i|
  email = "fila#{i + 1}@email.com"
  patient = User.find_or_create_by!(email: email) do |u|
    u.name       = Faker::Name.name
    u.password   = "123456"
    u.cpf        = format("%011d", rand(10_000_000_000..99_999_999_999))
    u.birth_date = Faker::Date.birthday(min_age: 18, max_age: 80)
    u.phone      = Faker::PhoneNumber.cell_phone
  end

  # Pula se já tiver triagem ativa na fila
  next if TriageSession.exists?(user: patient, status: :in_queue)

  urgency = URGENCY_LEVELS.sample
  weight  = TriageSetting.current.urgency_weight_for(urgency)
  queued_at = rand(10..120).minutes.ago

  session = TriageSession.create!(
    user:           patient,
    status:         :in_queue,
    initial_demand: DEMANDS[i],
    started_at:     queued_at - 15.minutes,
    finished_at:    queued_at - 2.minutes
  )

  # Mensagens de chat simuladas
  ChatMessage.create!(
    triage_session: session,
    sender:         "user",
    content:        DEMANDS[i],
    sent_at:        queued_at - 14.minutes,
    sequence:       1
  )
  ChatMessage.create!(
    triage_session: session,
    sender:         "ai",
    content:        "Entendido. Há quanto tempo você está com esse sintoma?",
    sent_at:        queued_at - 13.minutes,
    sequence:       2
  )
  ChatMessage.create!(
    triage_session: session,
    sender:         "user",
    content:        "Há cerca de #{rand(1..48)} horas.",
    sent_at:        queued_at - 12.minutes,
    sequence:       3
  )

  classification = AiClassification.create!(
    triage_session:          session,
    urgency_level:           urgency,
    summary:                 AI_SUMMARIES[i],
    ai_model:                "seed/faker",
    generated_at:            queued_at - 3.minutes,
    identified_symptoms:     [ DEMANDS[i].split.first(3).join(" ") ],
    classification_reasoning: "Análise automatizada de triagem baseada nos sintomas relatados.",
    protocol_reference:       "Protocolo Manchester",
    routing_suggestion:       "Encaminhar para avaliação médica imediata",
    confidence_score:         rand(70..99)
  )

  TriageValidation.create!(
    ai_classification:  classification,
    user:               colaborador_for_validation,
    decision:           :confirmed,
    final_urgency_level: urgency,
    validated_at:       queued_at - 1.minute
  )

  ticket = "#{Array.new(3) { ('A'..'Z').to_a.sample }.join}#{rand(10_000_000..99_999_999)}"

  QueueEntry.create!(
    triage_session: session,
    user:           patient,
    urgency_level:  urgency,
    urgency_weight: weight,
    status:         :waiting,
    queued_at:      queued_at,
    ticket_number:  ticket
  )

  print "."
end
puts "\n✓ 15 pacientes criados na fila de espera."

puts "\n══════════════════════════════════════════"
puts "  Seed concluído!"
puts "  Admin:        admin@admin.com / 123456789"
puts "  Colaborador:  colaborador1@triagemAI.com / 123456"
puts "  Especialista: especialista1@triagemAI.com / 123456"
puts "  Paciente:     paciente1@email.com / 123456"
puts "  Fila de teste: fila1@email.com / 123456"
puts "══════════════════════════════════════════"
