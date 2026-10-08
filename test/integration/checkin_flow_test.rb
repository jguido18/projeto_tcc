require "test_helper"

class CheckinFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    TriageSetting.delete_all
    @setting = TriageSetting.current
    @setting.update!(require_checkin: true, require_staff_validation: false)

    @patient = User.create!(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: "12345678901"
    )
    @session = TriageSession.create!(user: @patient, status: :in_triage, started_at: 10.minutes.ago)
    AiClassification.create!(
      triage_session: @session,
      urgency_level: "green",
      summary: "Resumo de teste",
      ai_model: "test-model",
      generated_at: Time.current,
      identified_symptoms: [ "sintoma-teste" ],
      confidence_score: 90
    )
    TriageService.new(@session).finalize_triage # triagem feita "de casa"
  end

  # ── Check-in pelo app do paciente ──

  test "patient checks in with the code shown on the TV and enters the queue" do
    sign_in @patient

    post api_triage_checkin_path, params: { code: CheckinCode.current }, as: :json

    assert_response :success
    assert @session.reload.in_queue?
    assert response.parsed_body.dig("session", "queue_entry", "ticket_number").present?
  end

  test "a wrong code is rejected and the patient stays out of the queue" do
    sign_in @patient
    wrong = CheckinCode.current.succ.rjust(6, "0")[-6..]

    post api_triage_checkin_path, params: { code: wrong }, as: :json

    assert_response :unprocessable_entity
    assert @session.reload.awaiting_checkin?
  end

  test "status endpoint exposes the check-in deadline" do
    sign_in @patient

    get api_triage_status_path, as: :json

    assert_equal "awaiting_checkin", response.parsed_body["status"]
    assert response.parsed_body["checkin_deadline"].present?
  end

  test "QR link survives the login redirect" do
    get "/app/queue?checkin=123456"
    assert_redirected_to new_user_session_path

    post user_session_path, params: { user: { email: @patient.email, password: "password123" } }

    assert_redirected_to "/app/queue?checkin=123456"
  end

  # ── Check-in pela recepção ──

  test "colaborador confirms presence for someone without a phone" do
    sign_in staff(colaborador: true)

    get validation_root_path
    assert_select ".checkin-item", text: /Paciente Teste/
    assert_select ".checkin-item", text: /\*\*\*\.456\.789-\*\*/ # CPF mascarado

    post validation_triage_session_check_in_path(@session)

    assert @session.reload.in_queue?
  end

  # ── TV da recepção ──

  test "public /tv does not show the check-in code" do
    get queue_tv_path
    assert_response :success
    assert_select ".tv-checkin", count: 0

    get tv_checkin_code_path, as: :json
    assert_response :forbidden
  end

  test "an authorized TV shows the check-in card and gets the current code" do
    sign_in staff(admin: true)
    post tv_activate_path
    sign_out :user # a autorização fica no navegador, não na conta

    get queue_tv_path
    assert_select ".tv-checkin"

    get tv_checkin_code_path, as: :json
    assert_response :success
    assert CheckinCode.valid?(response.parsed_body["code"])
    assert_includes response.parsed_body["qr_svg"], "<svg"
  end

  test "patients cannot authorize a TV" do
    sign_in @patient
    post tv_activate_path

    get tv_checkin_code_path, as: :json
    assert_response :forbidden
  end

  # ── Expiração ──

  test "triage without check-in expires after the configured deadline" do
    @setting.update!(checkin_expiration_hours: 6)

    travel 7.hours do
      ExpirePendingCheckinsJob.perform_now
    end

    assert @session.reload.expired?
  end

  test "triage within the deadline is kept" do
    @setting.update!(checkin_expiration_hours: 6)

    travel 2.hours do
      ExpirePendingCheckinsJob.perform_now
    end

    assert @session.reload.awaiting_checkin?
  end

  private

  def staff(**role)
    User.create!(
      name: "Equipe",
      email: "equipe-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      job_title: "Recepção",
      **role
    )
  end
end
