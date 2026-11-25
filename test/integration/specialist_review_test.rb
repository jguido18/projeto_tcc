require "test_helper"

class SpecialistReviewTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    TriageSetting.delete_all
    @setting = TriageSetting.current
    @setting.update!(require_staff_validation: false, specialist_review_enabled: true)

    @specialist = User.create!(
      name: "Especialista Teste",
      email: "especialista-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      specialist: true,
      job_title: "Médico"
    )

    patient = User.create!(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6)
    )
    session = TriageSession.create!(user: patient, status: :in_triage, started_at: 10.minutes.ago)
    @classification = AiClassification.create!(
      triage_session: session,
      urgency_level: "green",
      summary: "Resumo de teste",
      ai_model: "test-model",
      generated_at: Time.current,
      identified_symptoms: [ "sintoma-teste" ],
      confidence_score: 90
    )
    TriageService.new(session).finalize_triage # sem validação => já entra na fila
    @entry = session.reload.queue_entry
    @entry.update!(status: :called, called_at: Time.current)

    sign_in @specialist
  end

  test "attendance page shows the review form when the triage wasn't validated" do
    get attendance_attendance_path(@entry)

    assert_response :success
    assert_select "form[action=?]", review_classification_attendance_attendance_path(@entry)
  end

  test "attendance page hides the review form once the classification was reviewed" do
    post review_classification_attendance_attendance_path(@entry),
         params: { triage_validation: { final_urgency_level: "green" } }
    get attendance_attendance_path(@entry)

    assert_select "form[action=?]", review_classification_attendance_attendance_path(@entry), count: 0
  end

  test "validation panel hides the awaiting-validation column when the step is disabled" do
    admin = User.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com",
                         password: "password123", admin: true)
    sign_in admin

    get validation_root_path

    assert_response :success
    assert_select ".colaborador-column--validation", count: 0
    assert_select ".colaborador-panel--single"
  end

  test "admin settings page renders the flow toggles" do
    admin = User.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com",
                         password: "password123", admin: true)
    sign_in admin

    get edit_admin_triage_setting_path

    assert_response :success
    assert_select "input[name=?]", "triage_setting[require_staff_validation]"
    assert_select "input[name=?]", "triage_setting[specialist_review_enabled]"
  end

  test "admin saves the flow toggles" do
    admin = User.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com",
                         password: "password123", admin: true)
    sign_in admin

    patch admin_triage_setting_path, params: {
      triage_setting: {
        system_prompt: @setting.system_prompt,
        require_staff_validation: "1",
        specialist_review_enabled: "0",
        urgency_levels: @setting.urgency_levels.each_with_index.to_h { |level, i| [ i.to_s, level ] }
      }
    }

    @setting.reload
    assert @setting.require_staff_validation?
    assert_not @setting.specialist_review_enabled?
  end

  test "specialist confirms the AI classification" do
    post review_classification_attendance_attendance_path(@entry),
         params: { triage_validation: { final_urgency_level: "green" } }

    validation = @classification.reload.triage_validation
    assert validation.confirmed?
    assert_equal @specialist, validation.user
  end

  test "specialist adjusts the AI classification with a note" do
    post review_classification_attendance_attendance_path(@entry),
         params: { triage_validation: { final_urgency_level: "orange", notes: "Dor torácica não relatada à IA" } }

    validation = @classification.reload.triage_validation
    assert validation.adjusted?
    assert_equal "orange", validation.final_urgency_level
  end

  test "adjusting without a note is rejected" do
    post review_classification_attendance_attendance_path(@entry),
         params: { triage_validation: { final_urgency_level: "orange" } }

    assert_nil @classification.reload.triage_validation
  end

  # UC15 passo 05: a revisão do especialista entra no indicador do relatório.
  test "specialist review feeds the AI × team agreement indicator in the report" do
    post review_classification_attendance_attendance_path(@entry),
         params: { triage_validation: { final_urgency_level: "orange", notes: "Dor torácica não relatada à IA" } }
    sign_out @specialist
    sign_in User.create!(name: "Admin", email: "admin-#{SecureRandom.hex(4)}@example.com",
                         password: "password123", admin: true)

    get validation_reports_path(period: "today")

    assert_response :success
    assert_select ".rpt-kpi__label", text: /Concordância IA × equipe/
    assert_select ".rpt-kpi__value", text: "0.0%" # 1 revisão, nível ajustado → 0% de concordância
    assert_select ".rpt-kpi__breakdown-item--danger", text: /Subtriagem: 1/
  end

  test "review is refused when the admin disabled it" do
    @setting.update!(specialist_review_enabled: false)

    post review_classification_attendance_attendance_path(@entry),
         params: { triage_validation: { final_urgency_level: "green" } }

    assert_nil @classification.reload.triage_validation
  end
end
