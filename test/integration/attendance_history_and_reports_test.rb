require "test_helper"

class AttendanceHistoryAndReportsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    TriageSetting.delete_all
    @setting = TriageSetting.current

    @admin       = staff(admin: true, name: "Ana Admin")
    @colaborador = staff(colaborador: true, name: "Carla Colaboradora")
    @specialist  = staff(specialist: true, name: "Sérgio Especialista")
    @outro       = staff(colaborador: true, name: "Otávio Outro")

    # Atendimento completo: Carla validou (ajustando) e chamou, Sérgio finalizou
    @entry = completed_attendance(validator: @colaborador, caller: @colaborador, finisher: @specialist)
  end

  # ── Histórico do atendimento ──

  test "attendance page lists each step with who did it" do
    sign_in @specialist

    get attendance_attendance_path(@entry)

    assert_response :success
    assert_select "details.attendance-history:not([open])" # recolhido até clicar
    assert_select ".attendance-history__item", minimum: 5
    assert_select ".attendance-history__title", text: "Classificação validada pela equipe"
    assert_select ".attendance-history__title", text: "Paciente chamado"
    assert_select ".attendance-history__title", text: "Atendimento finalizado"
    assert_select ".attendance-history__actor", text: "Carla Colaboradora (Colaborador)"
    assert_select ".attendance-history__actor", text: "Sérgio Especialista (Especialista)"
    assert_select ".attendance-history__detail", text: /Ajustou de Pouco Urgente para Urgente/
  end

  test "timeline is in chronological order" do
    events = AttendanceTimeline.new(@entry.triage_session.reload).events

    assert_equal events.map(&:at), events.map(&:at).sort
    assert_equal "Triagem iniciada", events.first.title
    assert_equal "Atendimento finalizado", events.last.title
  end

  test "old attendances without the recorded caller show it as not recorded" do
    @entry.update!(called_by: nil)

    events = AttendanceTimeline.new(@entry.triage_session.reload).events

    assert_equal "Não registrado", events.find { |e| e.title == "Paciente chamado" }.actor
  end

  # ── Relatório: filtro por data ──

  test "a specific date shows only attendances finished that day" do
    old_entry = completed_attendance(validator: @colaborador, caller: @colaborador, finisher: @specialist,
                                     finished_at: 10.days.ago)
    sign_in @admin

    get validation_reports_path(date_from: 10.days.ago.to_date.iso8601)

    assert_response :success
    assert_select ".rpt-table tbody tr", count: 1
    assert_select ".rpt-table a[href=?]", attendance_attendance_path(old_entry)
  end

  test "a period includes every attendance finished inside it" do
    completed_attendance(validator: @colaborador, caller: @colaborador, finisher: @specialist, finished_at: 3.days.ago)
    completed_attendance(validator: @colaborador, caller: @colaborador, finisher: @specialist, finished_at: 40.days.ago)
    sign_in @admin

    get validation_reports_path(date_from: 5.days.ago.to_date.iso8601, date_to: Date.current.iso8601)

    assert_select ".rpt-table tbody tr", count: 2 # o de hoje e o de 3 dias atrás
  end

  # ── Relatório: filtro por colaborador ──

  test "staff filter keeps only attendances the person took part in" do
    completed_attendance(validator: @outro, caller: @outro, finisher: @specialist)
    sign_in @admin

    get validation_reports_path(period: "today", staff_id: @colaborador.id)

    assert_select ".rpt-table tbody tr", count: 1
    assert_select ".rpt-table__staff", text: /Carla Colaboradora/
    assert_select ".rpt-header__subtitle", text: /Carla Colaboradora/
  end

  test "specialist filter finds attendances they finished" do
    sign_in @admin

    get validation_reports_path(period: "today", staff_id: @specialist.id)

    assert_select ".rpt-table tbody tr", count: 1
  end

  test "CSV export respects the filters and lists who did each step" do
    completed_attendance(validator: @outro, caller: @outro, finisher: @specialist)
    sign_in @admin

    get validation_reports_export_path(period: "today", staff_id: @colaborador.id)

    rows = CSV.parse(response.body.delete_prefix("\xEF\xBB\xBF"), col_sep: ";", headers: true)
    assert_equal 1, rows.size
    assert_equal "Carla Colaboradora", rows.first["Validado por"]
    assert_equal "Carla Colaboradora", rows.first["Chamado por"]
    assert_equal "Sérgio Especialista", rows.first["Finalizado por"]
  end

  test "AI accuracy compares the AI level with the final level, not the decision field" do
    # Registro antigo: gravado como "confirmado", mas com o nível alterado.
    legacy = completed_attendance(validator: @colaborador, caller: @colaborador, finisher: @specialist)
    legacy.triage_session.ai_classification.triage_validation.update_column(:decision, "confirmed")
    # Concordância real: IA e equipe no mesmo nível.
    agreed = completed_attendance(validator: @colaborador, caller: @colaborador, finisher: @specialist)
    agreed.triage_session.ai_classification.triage_validation.update_columns(decision: "confirmed",
                                                                             final_urgency_level: "green")
    sign_in @admin

    get validation_reports_path(period: "today")

    # 3 validações hoje (setup + 2), só 1 concorda com a IA → 33,3%; 2 subtriagens
    assert_select ".rpt-kpi__value", text: "33.3%"
    assert_select ".rpt-kpi__breakdown-item--danger", text: /Subtriagem: 2/
  end

  test "invalid dates fall back to the default period instead of erroring" do
    sign_in @admin

    get validation_reports_path(date_from: "31/02/abc")

    assert_response :success
  end

  private

  def staff(**attrs)
    User.create!({ email: "equipe-#{SecureRandom.hex(4)}@example.com", password: "password123",
                   job_title: "Cargo" }.merge(attrs))
  end

  # Triagem → validação (ajustada de verde para amarelo) → fila → chamado → finalizado
  def completed_attendance(validator:, caller:, finisher:, finished_at: Time.current)
    patient = User.create!(name: "Paciente #{SecureRandom.hex(2)}", email: "p-#{SecureRandom.hex(4)}@example.com",
                           password: "password123", cpf: SecureRandom.hex(6))
    start = finished_at - 1.hour
    session = TriageSession.create!(user: patient, status: :in_queue, started_at: start)
    ai = AiClassification.create!(triage_session: session, urgency_level: "green", summary: "Resumo",
                                  ai_model: "test", generated_at: start + 10.minutes,
                                  identified_symptoms: [ "x" ], confidence_score: 80)
    TriageValidation.create!(ai_classification: ai, user: validator, decision: :adjusted,
                             final_urgency_level: "yellow", notes: "Febre alta", validated_at: start + 15.minutes)
    entry = QueueEntry.create!(triage_session: session, user: patient, urgency_level: "yellow", status: :completed,
                               queued_at: start + 15.minutes, ticket_number: SecureRandom.alphanumeric(9).upcase,
                               called_at: start + 30.minutes, called_by: caller,
                               service_finished_at: finished_at, finished_by: finisher)
    session.update!(status: :completed, finished_at: finished_at)
    entry
  end
end
