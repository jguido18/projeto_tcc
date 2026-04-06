class AiService
  OPENAI_DEFAULT_MODEL = "gpt-4o-mini"
  ANTHROPIC_DEFAULT_MODEL = "claude-opus-4-6"
  MAX_TOKENS = 1024

  def initialize(triage_session)
    @session = triage_session
  end

  # Sends the conversation history to the LLM and returns the AI reply text.
  # Returns a hash: { content: String, raw_response: Hash, finished: Boolean }
  def call(user_message)
    case provider
    when :openai
      call_openai(user_message)
    when :anthropic
      call_anthropic(user_message)
    else
      raise "Unsupported AI provider: #{provider}"
    end
  end

  # Asks the AI to produce a structured JSON classification based on the full chat history.
  # Returns a hash matching AiClassification fields.
  def classify
    raw_text = case provider
    when :openai
      classify_openai
    when :anthropic
      classify_anthropic
    else
      raise "Unsupported AI provider: #{provider}"
    end

    JSON.parse(extract_json(raw_text))
  rescue JSON::ParserError
    raise "AI returned invalid JSON for classification"
  end

  def model_identifier
    case provider
    when :openai
      openai_model
    when :anthropic
      anthropic_model
    end
  end

  private

  def provider
    @provider ||= begin
      configured = ENV["AI_PROVIDER"].to_s.strip.downcase
      if configured == "openai"
        :openai
      elsif configured == "anthropic"
        :anthropic
      elsif openai_key.present?
        :openai
      elsif anthropic_key.present?
        :anthropic
      else
        raise "Configure OPENAI_API_KEY (ou ANTHROPIC_API_KEY) via ENV ou credentials."
      end
    end
  end

  def openai_client
    require "openai"
    @openai_client ||= OpenAI::Client.new(access_token: openai_key)
  end

  def anthropic_client
    @anthropic_client ||= Anthropic::Client.new(api_key: anthropic_key)
  end

  def openai_key
    ENV["OPENAI_API_KEY"] || Rails.application.credentials.openai_api_key
  end

  def anthropic_key
    ENV["ANTHROPIC_API_KEY"] || Rails.application.credentials.anthropic_api_key
  end

  def openai_model
    ENV["OPENAI_MODEL"].presence || OPENAI_DEFAULT_MODEL
  end

  def anthropic_model
    ENV["ANTHROPIC_MODEL"].presence || ANTHROPIC_DEFAULT_MODEL
  end

  def call_openai(user_message)
    response = openai_client.chat(
      parameters: {
        model: openai_model,
        max_tokens: MAX_TOKENS,
        temperature: 0.3,
        messages: [
          { role: "system", content: system_prompt },
          *build_messages(user_message)
        ]
      }
    )

    content = response.dig("choices", 0, "message", "content").to_s

    {
      content: content,
      raw_response: response,
      finished: triage_finished?(content)
    }
  end

  def call_anthropic(user_message)
    messages = build_messages(user_message)
    response = anthropic_client.messages.create(
      model: anthropic_model,
      max_tokens: MAX_TOKENS,
      system: system_prompt,
      messages: messages
    )

    content = response.content.first.text

    {
      content: content,
      raw_response: response.to_h,
      finished: triage_finished?(content)
    }
  end

  def classify_openai
    response = openai_client.chat(
      parameters: {
        model: openai_model,
        max_tokens: MAX_TOKENS,
        temperature: 0.0,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: classification_system_prompt },
          *build_classification_messages
        ]
      }
    )

    response.dig("choices", 0, "message", "content").to_s
  end

  def classify_anthropic
    response = anthropic_client.messages.create(
      model: anthropic_model,
      max_tokens: MAX_TOKENS,
      system: classification_system_prompt,
      messages: build_classification_messages
    )

    response.content.first.text.to_s
  end

  def extract_json(raw_text)
    text = raw_text.to_s.strip
    return text if text.start_with?("{") && text.end_with?("}")

    fenced = text.match(/```(?:json)?\s*(\{.*\})\s*```/m)
    return fenced[1] if fenced

    object = text.match(/\{.*\}/m)
    return object[0] if object

    text
  end

  def system_prompt
    setting = TriageSetting.current
    [
      setting.purpose.presence,
      setting.system_prompt
    ].compact.join("\n\n")
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
      "#{msg.user? ? 'Solicitante' : 'IA'}: #{msg.content}"
    end.join("\n")

    [ { role: "user", content: "Transcrição da triagem:\n#{transcript}" } ]
  end

  def triage_finished?(content)
    # The AI signals end of triage by including this marker in its response
    content.downcase.include?("[triagem_concluida]")
  end

  def classification_system_prompt
    setting = TriageSetting.current
    levels = setting.urgency_levels.map { |level| "#{level['key']} (#{level['label']}, prioridade=#{level['weight']})" }.join(", ")

    <<~PROMPT
      Você é um sistema de classificação de triagem.
      Com base na transcrição da triagem fornecida, retorne um JSON com exatamente estes campos:
      {
        "urgency_level": "uma chave válida da configuração",
        "protocol_reference": "código ou referência opcional do protocolo usado",
        "summary": "resumo da classificação em 1-2 frases",
        "identified_symptoms": ["sintoma1", "sintoma2"],
        "ai_suggestion": "sugestão geral de ação",
        "classification_reasoning": "raciocínio da classificação detalhado",
        "routing_suggestion": "destino ou fila recomendada",
        "confidence_score": 85.0
      }
      Níveis de urgência válidos: #{levels}
      Regra de prioridade: 1 é o nível mais urgente e 10 é o menos urgente.
      Escolha urgency_level respeitando essa ordem numérica de prioridade.
      Retorne apenas o JSON, sem texto adicional.
    PROMPT
  end
end
