require "test_helper"

class AdminFixesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    TriageSetting.delete_all
    @setting = TriageSetting.current
    @admin = User.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com",
                          password: "password123", admin: true)
  end

  # ── 1. Prompt vazio ──

  test "saving a blank system prompt shows an error instead of silently restoring the default" do
    @setting.update!(system_prompt: "Prompt personalizado da secretaria")
    sign_in @admin

    patch admin_triage_setting_path, params: { triage_setting: settings_params(system_prompt: "") }

    assert_response :unprocessable_entity
    assert_match "Prompt", response.body
    assert_equal "Prompt personalizado da secretaria", @setting.reload.system_prompt
  end

  # ── 2. Login de equipe ──

  test "inactive staff member stays on the staff login page" do
    staff = create_staff(colaborador: true, active: false)

    post staff_session_path, params: { user: { email: staff.email, password: "password123" } }

    assert_redirected_to new_staff_session_path
    follow_redirect!
    assert_match "desativada", response.body
  end

  test "wrong password on the staff login re-renders the staff login page" do
    staff = create_staff(colaborador: true)

    post staff_session_path, params: { user: { email: staff.email, password: "senha-errada" } }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", staff_session_path
  end

  test "inactive patient still goes back to the patient login" do
    patient = User.create!(name: "Paciente", email: "p-#{SecureRandom.hex(4)}@example.com",
                           password: "password123", cpf: SecureRandom.hex(6), active: false)

    post user_session_path, params: { user: { email: patient.email, password: "password123" } }

    assert_redirected_to new_user_session_path
  end

  # ── 3. Colaborador + especialista ──

  test "creating a staff member with both roles shows the error in Portuguese" do
    sign_in @admin

    post admin_users_path, params: { user: {
      name: "Dois Perfis", email: "dois-#{SecureRandom.hex(4)}@example.com", job_title: "Enfermeiro",
      password: "password123", password_confirmation: "password123", colaborador: "1", specialist: "1"
    } }

    assert_response :unprocessable_entity
    assert_match "especialista e colaborador ao mesmo tempo", response.body
    assert_no_match "cannot be both", response.body
  end

  # ── 4. Exclusão de quem participou de atendimento ──

  test "staff member who never took part in an attendance can be deleted" do
    staff = create_staff(colaborador: true)
    sign_in @admin

    delete admin_user_path(staff)

    assert_nil User.find_by(id: staff.id)
  end

  test "staff member who validated a triage cannot be deleted" do
    colaborador = create_staff(colaborador: true)
    entry = queued_entry
    TriageValidation.create!(ai_classification: entry.triage_session.ai_classification, user: colaborador,
                             decision: :confirmed, final_urgency_level: "green", validated_at: Time.current)
    sign_in @admin

    delete admin_user_path(colaborador)

    assert User.exists?(colaborador.id)
    assert_redirected_to admin_users_path
  end

  test "staff member who called a patient cannot be deleted" do
    colaborador = create_staff(colaborador: true)
    entry = queued_entry
    sign_in colaborador
    patch call_validation_queue_entry_path(entry)
    sign_out :user

    sign_in @admin
    delete admin_user_path(colaborador)

    assert User.exists?(colaborador.id)
  end

  test "specialist who finished an attendance cannot be deleted" do
    specialist = create_staff(specialist: true)
    entry = queued_entry
    entry.update!(status: :called, called_at: Time.current)
    sign_in specialist
    patch finish_attendance_attendance_path(entry)
    sign_out :user

    sign_in @admin
    delete admin_user_path(specialist)

    assert User.exists?(specialist.id)
  end

  test "reception staff who checked a patient in cannot be deleted" do
    @setting.update!(require_checkin: true)
    colaborador = create_staff(colaborador: true)
    session = triage_session
    TriageService.new(session).finalize_triage
    sign_in colaborador
    post validation_triage_session_check_in_path(session)
    sign_out :user

    sign_in @admin
    delete admin_user_path(colaborador)

    assert User.exists?(colaborador.id)
  end

  test "team list shows the locked badge instead of delete for staff who took part in attendances" do
    participant = create_staff(colaborador: true)
    entry = queued_entry
    entry.update!(status: :called, called_at: Time.current, called_by: participant)
    newcomer = create_staff(colaborador: true)
    sign_in @admin

    get admin_users_path

    assert_select "form[action=?]", admin_user_path(participant), count: 0
    assert_select "form[action=?]", admin_user_path(newcomer)
    assert_select ".admin-action--locked"
  end

  private

  def settings_params(**overrides)
    {
      purpose: @setting.purpose,
      system_prompt: @setting.system_prompt,
      hint_example: @setting.hint_example,
      urgency_levels: @setting.urgency_levels.each_with_index.to_h { |level, i| [ i.to_s, level ] }
    }.merge(overrides)
  end

  def create_staff(**attrs)
    User.create!({ name: "Equipe #{SecureRandom.hex(2)}", email: "equipe-#{SecureRandom.hex(4)}@example.com",
                   password: "password123", job_title: "Cargo" }.merge(attrs))
  end

  def triage_session
    patient = User.create!(name: "Paciente", email: "paciente-#{SecureRandom.hex(4)}@example.com",
                           password: "password123", cpf: SecureRandom.hex(6))
    session = TriageSession.create!(user: patient, status: :in_triage, started_at: 10.minutes.ago)
    AiClassification.create!(triage_session: session, urgency_level: "green", summary: "Resumo",
                             ai_model: "test", generated_at: Time.current, identified_symptoms: [ "x" ],
                             confidence_score: 90)
    session
  end

  # Paciente já na fila (validação da equipe desligada para simplificar)
  def queued_entry
    @setting.update!(require_staff_validation: false)
    session = triage_session
    TriageService.new(session).finalize_triage
    session.reload.queue_entry
  end
end
