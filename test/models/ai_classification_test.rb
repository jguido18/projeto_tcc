require "test_helper"

class AiClassificationTest < ActiveSupport::TestCase
  setup do
    TriageSetting.delete_all
    TriageSetting.current.update!(confidence_threshold: 70)

    user = User.create!(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6)
    )
    @session = TriageSession.create!(user: user, status: :awaiting_validation, started_at: 1.hour.ago)
  end

  test "needs_review? is true when confidence_score is blank" do
    classification = build_classification(confidence_score: nil)

    assert classification.needs_review?
  end

  test "needs_review? is true when confidence_score is below the configured threshold" do
    classification = build_classification(confidence_score: 55)

    assert classification.needs_review?
  end

  test "needs_review? is false when confidence_score meets the configured threshold" do
    classification = build_classification(confidence_score: 90)

    assert_not classification.needs_review?
  end

  private

  def build_classification(confidence_score:)
    AiClassification.create!(
      triage_session: @session,
      urgency_level: "green",
      summary: "Resumo de teste",
      ai_model: "test-model",
      generated_at: Time.current,
      identified_symptoms: [ "sintoma-teste" ],
      confidence_score: confidence_score
    )
  end
end
