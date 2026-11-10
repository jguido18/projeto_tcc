require "test_helper"

# Fluxos alternativos das fichas de caso de uso (Apêndice B do TCC) que não
# estavam cobertos por outros testes. O nome de cada teste começa pelo UC/fluxo.
class UseCaseAlternativesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    TriageSetting.delete_all
    @setting = TriageSetting.current
  end

  # ── UC01 – Cadastro do solicitante ──

  test "UC01 A01: CPF ausente é recusado" do
    user = build_patient(cpf: nil)

    assert_not user.valid?
    assert user.errors[:cpf].any?
  end

  test "UC01 A01: CPF já cadastrado é recusado" do
    build_patient(cpf: "11122233344").save!
    duplicate = build_patient(cpf: "11122233344")

    assert_not duplicate.valid?
    assert duplicate.errors[:cpf].any?
  end

  test "UC01 A03: recuperação de senha gera token e envia e-mail" do
    user = build_patient
    user.save!

    assert_emails 1 do
      post user_password_path, params: { user: { email: user.email } }
    end
    assert user.reload.reset_password_token.present?
  end

  # ── UC02 – Login da equipe ──

  test "UC02: cada perfil da equipe entra pelo /staff/login e cai no seu painel" do
    {
      { colaborador: true } => validation_root_path,
      { specialist: true }  => attendance_root_path,
      { admin: true }       => edit_admin_triage_setting_path
    }.each do |roles, destination|
      user = staff(**roles)
      post staff_session_path, params: { user: { email: user.email, password: "password123" } }
      assert_redirected_to destination
      delete destroy_staff_session_path
    end
  end

  # ── UC03 – Perfil e prioridade legal ──

  test "UC03 A01: condição temporária sem validade é recusada" do
    user = build_patient(gestante: true, gestante_valid_until: nil)

    assert_not user.valid?
    assert user.errors[:gestante_valid_until].any?
  end

  test "UC03 A01: condição temporária com validade vencida é recusada" do
    user = build_patient(lactante: true, lactante_valid_until: 1.day.ago.to_date)

    assert_not user.valid?
    assert_includes user.errors[:lactante_valid_until], "não pode ser uma data no passado"
  end

  test "UC03 A02: altura e peso fora da faixa são recusados" do
    assert_not build_patient(height_cm: 40).valid?
    assert_not build_patient(height_cm: 300).valid?
    assert_not build_patient(weight_kg: 0.5).valid?
    assert_not build_patient(weight_kg: 500).valid?
    assert build_patient(height_cm: 170, weight_kg: 70).valid?
  end

  # ── UC09 – Validação pelo colaborador ──

  test "UC09: nível alterado é gravado como ajuste mesmo que o formulário envie 'confirmed'" do
    session = awaiting_validation_session(ai_level: "yellow")
    sign_in staff(colaborador: true)

    post validation_triage_validations_path, params: { triage_validation: {
      triage_session_id: session.id, final_urgency_level: "green", decision: "confirmed",
      notes: "Sem sinais de alarme"
    } }

    validation = session.reload.ai_classification.triage_validation
    assert validation.adjusted?
    assert_equal "green", validation.final_urgency_level
    assert session.in_queue?
  end

  test "UC09 A01: ajuste sem observação é recusado" do
    session = awaiting_validation_session(ai_level: "yellow")
    sign_in staff(colaborador: true)

    post validation_triage_validations_path, params: { triage_validation: {
      triage_session_id: session.id, final_urgency_level: "green", decision: "confirmed", notes: ""
    } }

    assert_response :unprocessable_entity
    assert session.reload.awaiting_validation?
  end

  test "UC09: confirmar sem alterar o nível não exige observação" do
    session = awaiting_validation_session(ai_level: "yellow")
    sign_in staff(colaborador: true)

    post validation_triage_validations_path, params: { triage_validation: {
      triage_session_id: session.id, final_urgency_level: "yellow", decision: "confirmed"
    } }

    assert session.reload.ai_classification.triage_validation.confirmed?
    assert session.in_queue?
  end

  test "UC09: triagem já validada não pode ser validada de novo" do
    session = awaiting_validation_session(ai_level: "yellow")
    sign_in staff(colaborador: true)
    params = { triage_validation: { triage_session_id: session.id, final_urgency_level: "yellow" } }

    post validation_triage_validations_path, params: params
    post validation_triage_validations_path, params: params

    assert_redirected_to validation_root_path
    assert_equal 1, QueueEntry.where(triage_session: session).count
  end

  # ── UC17 – Configuração da IA ──

  test "UC17 A02: limiar fora de 0–100 e prazo fora de 1–72h são recusados" do
    assert_not @setting.tap { |s| s.confidence_threshold = 101 }.valid?
    @setting.reload
    assert_not @setting.tap { |s| s.checkin_expiration_hours = 0 }.valid?
    @setting.reload
    assert_not @setting.tap { |s| s.checkin_expiration_hours = 73 }.valid?
  end

  test "UC17 A03: lista sem níveis válidos e chaves duplicadas são recusadas" do
    @setting.urgency_levels = [ { "key" => "x", "label" => "" } ]
    assert_not @setting.valid?

    @setting.urgency_levels = [
      { "key" => "a", "label" => "A", "weight" => 1 },
      { "key" => "a", "label" => "B", "weight" => 2 }
    ]
    assert_not @setting.valid?
  end

  test "UC17 A03: peso fora de 1–10 nunca é salvo (ajustado ao limite)" do
    @setting.update!(urgency_levels: [ { "key" => "a", "label" => "A", "weight" => 50 } ])

    assert_equal 10, @setting.reload.urgency_levels.first["weight"]
  end

  test "UC17 A04: cor inválida cai para o cinza padrão" do
    @setting.update!(urgency_levels: [ { "key" => "a", "label" => "A", "weight" => 1, "color" => "azul" } ])

    assert_equal "#718096", @setting.reload.urgency_levels.first["color"]
  end

  test "UC17 A05: não pode existir um segundo registro de configuração" do
    assert_not TriageSetting.new(system_prompt: "outro").valid?
  end

  # ── UC18 – Equipe ──

  test "UC18 A01: cargo é obrigatório para colaborador e especialista" do
    %i[colaborador specialist].each do |role|
      user = User.new(name: "Equipe", email: "eq-#{SecureRandom.hex(4)}@example.com",
                      password: "password123", role => true, job_title: nil)
      assert_not user.valid?
      assert user.errors[:job_title].any?
    end
  end

  private

  def build_patient(**attrs)
    User.new({
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6)
    }.merge(attrs))
  end

  def awaiting_validation_session(ai_level:)
    @setting.update!(require_staff_validation: true, require_checkin: false)
    patient = build_patient.tap(&:save!)
    session = TriageSession.create!(user: patient, status: :in_triage, started_at: 10.minutes.ago)
    AiClassification.create!(
      triage_session: session, urgency_level: ai_level, summary: "Resumo de teste",
      ai_model: "test-model", generated_at: Time.current,
      identified_symptoms: [ "sintoma-teste" ], confidence_score: 90
    )
    TriageService.new(session).finalize_triage
    session.reload
  end

  def staff(**roles)
    User.create!(name: "Equipe Teste", email: "equipe-#{SecureRandom.hex(4)}@example.com",
                 password: "password123", job_title: "Recepção", **roles)
  end
end
