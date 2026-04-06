class AiService
  MODEL = "claude-opus-4-6"
  MAX_TOKENS = 1024

  def initialize(triage_session)
    @session = triage_session
    @establishment = triage_session.establishment
  end

  # Sends the conversation history to the LLM and returns the AI reply text.
  # Returns a hash: { content: String, raw_response: Hash, finished: Boolean }
  def call(user_message)
    messages = build_messages(user_message)
    response = client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: system_prompt,
      messages: messages
    )

    content = response.content.first.text
    finished = triage_finished?(content)

    {
      content: content,
      raw_response: response.to_h,
      finished: finished
    }
  end

  # Asks the AI to produce a structured JSON classification based on the full chat history.
  # Returns a hash matching AiClassification fields.
  def classify
    messages = build_classification_messages
    response = client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: classification_system_prompt,
      messages: messages
    )

    JSON.parse(response.content.first.text)
  rescue JSON::ParserError
    raise "AI returned invalid JSON for classification"
  end

  private

  def client
    key = ENV["ANTHROPIC_API_KEY"] ||
          Rails.application.credentials.anthropic_api_key
    raise "ANTHROPIC_API_KEY não configurada. Defina via ENV ou Rails credentials." if key.blank?
    @client ||= Anthropic::Client.new(api_key: key)
  end

  def system_prompt
    @establishment.system_prompt
  end

  def build_messages(user_message)
    history = @session.chat_messages.map do |msg|
      { role: msg.user? ? "user" : "assistant", content: msg.content }
    end
    history << { role: "user", content: user_message }
    history
  end

  def build_classification_messages
    transcript = @session.chat_messages.map do |msg|
      "#{msg.user? ? 'Paciente' : 'IA'}: #{msg.content}"
    end.join("\n")

    [ { role: "user", content: "Transcrição da triagem:\n#{transcript}" } ]
  end

  def triage_finished?(content)
    # The AI signals end of triage by including this marker in its response
    content.downcase.include?("[triagem_concluida]")
  end

  def classification_system_prompt
    <<~PROMPT
      Você é um sistema de classificação de triagem médica.
      Com base na transcrição da triagem fornecida, retorne um JSON com exatamente estes campos:
      {
        "urgency_level": "red|orange|yellow|green|blue",
        "manchester_code": "código opcional",
        "summary": "resumo clínico em 1-2 frases",
        "identified_symptoms": ["sintoma1", "sintoma2"],
        "ai_suggestion": "sugestão de encaminhamento",
        "clinical_reasoning": "raciocínio clínico detalhado",
        "specialty_suggestion": "especialidade recomendada",
        "confidence_score": 85.0
      }
      Retorne apenas o JSON, sem texto adicional.
    PROMPT
  end
end
