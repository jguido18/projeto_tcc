require "test_helper"

class AiServiceTest < ActiveSupport::TestCase
  setup do
    user = User.create!(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6)
    )
    session = TriageSession.create!(user: user, status: :in_triage, started_at: Time.current)
    @service = AiService.new(session)
  end

  # O campo "finished" no JSON é o sinal principal de encerramento — mais
  # confiável do que depender só do marcador [triagem_concluida] solto no
  # meio do texto (modelos às vezes esquecem de incluir o marcador, mesmo
  # instruídos, mas seguem campos de schema com muito mais consistência).
  test "parse_chat_reply reads finished: true from the JSON payload" do
    raw = { content: "Sua classificação é moderada.", suggested_replies: [], finished: true }.to_json

    reply = @service.send(:parse_chat_reply, raw)

    assert_equal true, reply[:finished]
  end

  test "parse_chat_reply defaults finished to false when the field is absent" do
    raw = { content: "Há quanto tempo você sente isso?", suggested_replies: [ "Hoje", "Ontem" ] }.to_json

    reply = @service.send(:parse_chat_reply, raw)

    assert_equal false, reply[:finished]
  end

  test "parse_chat_reply defaults finished to false when the AI response isn't valid JSON" do
    reply = @service.send(:parse_chat_reply, "texto solto, sem JSON nenhum")

    assert_equal false, reply[:finished]
  end

  test "triage_finished? is true when the finished field is true, even without the text marker" do
    assert @service.send(:triage_finished?, "Aguarde a validação da equipe.", finished_field: true)
  end

  test "triage_finished? falls back to the text marker when the field is false/missing" do
    assert @service.send(:triage_finished?, "Encerrando. [triagem_concluida]", finished_field: false)
  end

  test "triage_finished? is false when neither signal is present" do
    assert_not @service.send(:triage_finished?, "Só mais uma pergunta.", finished_field: false)
  end
end
