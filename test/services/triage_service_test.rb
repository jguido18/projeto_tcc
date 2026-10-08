require "test_helper"

class TriageServiceTest < ActiveSupport::TestCase
  setup do
    TriageSetting.delete_all
    @setting = TriageSetting.current

    user = User.create!(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6)
    )
    @session = TriageSession.create!(user: user, status: :in_triage, started_at: 10.minutes.ago)

    # Classificação já existente => finalize_triage não chama a IA de verdade.
    AiClassification.create!(
      triage_session: @session,
      urgency_level: "yellow",
      summary: "Resumo de teste",
      ai_model: "test-model",
      generated_at: Time.current,
      identified_symptoms: [ "sintoma-teste" ],
      confidence_score: 90
    )
  end

  test "with staff validation required, finalize_triage waits for a colaborador" do
    @setting.update!(require_staff_validation: true)

    TriageService.new(@session).finalize_triage

    assert @session.reload.awaiting_validation?
    assert_nil @session.queue_entry
  end

  test "without staff validation, finalize_triage puts the patient straight in the queue" do
    @setting.update!(require_staff_validation: false)

    TriageService.new(@session).finalize_triage

    assert @session.reload.in_queue?
    entry = @session.queue_entry
    assert entry.waiting?
    assert_equal "yellow", entry.urgency_level # vem direto da classificação da IA
  end

  test "with check-in required, finalize_triage stops at awaiting_checkin" do
    @setting.update!(require_checkin: true, require_staff_validation: false)

    TriageService.new(@session).finalize_triage

    assert @session.reload.awaiting_checkin?
    assert_nil @session.queue_entry
  end

  test "check_in! moves on to the queue, and the wait time starts at check-in, not at triage" do
    @setting.update!(require_checkin: true, require_staff_validation: false)
    TriageService.new(@session).finalize_triage # triagem "de casa"

    travel 2.hours do
      assert TriageService.new(@session.reload).check_in!

      entry = @session.reload.queue_entry
      assert @session.in_queue?
      assert_in_delta Time.current, @session.checked_in_at, 1.second
      # queued_at nasce no check-in: quem triou em casa não chega "envelhecido"
      assert_in_delta Time.current, entry.queued_at, 1.second
    end
  end

  test "check_in! goes to staff validation when that step is required" do
    @setting.update!(require_checkin: true, require_staff_validation: true)
    TriageService.new(@session).finalize_triage

    TriageService.new(@session.reload).check_in!

    assert @session.reload.awaiting_validation?
    assert_nil @session.queue_entry
  end

  test "a second check-in (e.g. app and reception at once) doesn't queue twice" do
    @setting.update!(require_checkin: true, require_staff_validation: false)
    TriageService.new(@session).finalize_triage

    assert TriageService.new(@session.reload).check_in!
    assert_not TriageService.new(@session.reload).check_in!
    assert_equal 1, QueueEntry.where(triage_session: @session).count
  end
end
