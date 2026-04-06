require "faker"
I18n.locale = :en
Faker::Config.locale = :en

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
  admin.email       = "admin@triagemAI.com"
  admin.name        = "Administrador"
  admin.password    = "123456"
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
    u.name        = Faker::Name.full_name
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
    u.name       = Faker::Name.full_name
    u.password   = "123456"
    u.specialist = true
    u.job_title  = "specialist"
    u.active     = [ true, true, true, false ].sample
  end
  print "."
end
puts "\n✓ 12 especialistas criados."

# ── Pacientes (usuários comuns) ───────────────────────────────────────────────
30.times do |i|
  email = "paciente#{i + 1}@email.com"
  User.find_or_create_by!(email: email) do |u|
    u.name       = Faker::Name.full_name
    u.password   = "123456"
    u.cpf        = Faker::Number.number(digits: 11).to_s
    u.birth_date = Faker::Date.birthday(min_age: 18, max_age: 80)
    u.phone      = Faker::PhoneNumber.cell_phone
  end
  print "."
end
puts "\n✓ 30 pacientes criados."

puts "\n══════════════════════════════════════════"
puts "  Seed concluído!"
puts "  Admin:        admin@triagemAI.com / 123456"
puts "  Colaborador:  colaborador1@triagemAI.com / 123456"
puts "  Especialista: especialista1@triagemAI.com / 123456"
puts "  Paciente:     paciente1@email.com / 123456"
puts "══════════════════════════════════════════"
