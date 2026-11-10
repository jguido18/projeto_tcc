class AiService
  OPENAI_DEFAULT_MODEL = "gpt-4o-mini"
  ANTHROPIC_DEFAULT_MODEL = "claude-opus-4-6"
  MAX_TOKENS = 1024

  def initialize(triage_session)
    @session = triage_session
  end

  # Sends the conversation history to the LLM and returns the AI reply text.
  # document_context: { type: :image, base64: String, content_type: String }
  #                 | { type: :text,  text: String }
  #                 | nil
  # Returns a hash: { content: String, suggested_replies: Array<String>, raw_response: Hash, finished: Boolean }
  def call(user_message, document_context: nil)
    case provider
    when :openai
      call_openai(user_message, document_context: document_context)
    when :anthropic
      call_anthropic(user_message, document_context: document_context)
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

  def call_openai(user_message, document_context: nil)
    response = openai_client.chat(
      parameters: {
        model: openai_model,
        max_tokens: MAX_TOKENS,
        temperature: 0.3,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt(document_present: document_context.present?) },
          *build_messages(user_message, document_context: document_context)
        ]
      }
    )

    reply = parse_chat_reply(response.dig("choices", 0, "message", "content"))
    finished = triage_finished?(reply[:content], finished_field: reply[:finished])

    {
      content: strip_marker(reply[:content]),
      suggested_replies: reply[:suggested_replies],
      raw_response: merge_reply_metadata(response, reply[:suggested_replies]),
      finished: finished
    }
  end

  def call_anthropic(user_message, document_context: nil)
    messages = build_messages(user_message, document_context: document_context)
    response = anthropic_client.messages.create(
      model: anthropic_model,
      max_tokens: MAX_TOKENS,
      system: system_prompt(document_present: document_context.present?),
      messages: messages
    )

    reply = parse_chat_reply(response.content.first.text)
    finished = triage_finished?(reply[:content], finished_field: reply[:finished])

    {
      content: strip_marker(reply[:content]),
      suggested_replies: reply[:suggested_replies],
      raw_response: merge_reply_metadata(response.to_h, reply[:suggested_replies]),
      finished: finished
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

  def parse_chat_reply(raw_content)
    payload = JSON.parse(extract_json(raw_content.to_s))
    content = payload["content"].to_s.strip

    if content.blank?
      raise JSON::ParserError, "AI returned empty content"
    end

    {
      content: content,
      suggested_replies: normalize_suggested_replies(payload["suggested_replies"], content),
      finished: payload["finished"] == true
    }
  rescue JSON::ParserError
    content = raw_content.to_s.strip

    {
      content: content,
      suggested_replies: fallback_suggested_replies(content),
      finished: false
    }
  end

  def normalize_suggested_replies(replies, content)
    Array(replies)
      .filter_map { |reply| reply.to_s.strip.presence }
      .select { |reply| valid_suggested_reply?(reply, content) }
      .uniq
      .first(4)
      .yield_self { |items| items.presence || fallback_suggested_replies(content) }
  end

  def valid_suggested_reply?(reply, content)
    return false if reply.include?("?")
    return false if field_label_reply?(reply)
    return false if reply.to_s.strip.length > 80

    # Accept common numeric-scale answers like "0 a 3" or "7-10".
    return true if numeric_scale_reply?(reply)

    normalized_reply = normalized_tokens(reply)
    normalized_content = normalized_tokens(content)

    return false if normalized_reply.empty?
    return false if normalized_reply == normalized_content

    true
  end

  def numeric_scale_reply?(reply)
    text = reply.to_s
      .downcase
      .unicode_normalize(:nfkd)
      .gsub(/\s+/, " ")
      .strip

    text.match?(/\A\d+\s*(?:a|-|ate)\s*\d+\b/)
  end

  def field_label_reply?(reply)
    normalized = reply.to_s
      .downcase
      .unicode_normalize(:nfkd)
      .gsub(/[^a-z0-9\s]/, " ")
      .squeeze(" ")
      .strip

    [
      /\Anome( completo)?\z/,
      /\Acurso( e semestre)?\z/,
      /\Asemestre\z/,
      /\Acurso\z/,
      /\Atelefone\z/,
      /\Aemail\z/,
      /\Acpf\z/,
      /\Aidade\z/,
      /\Aendereco\z/,
      /\Amatricula\z/,
      /\Adocumento\z/
    ].any? { |pattern| pattern.match?(normalized) }
  end

  def normalized_tokens(text)
    text.to_s
      .downcase
      .unicode_normalize(:nfkd)
      .gsub(/[^a-z0-9\s]/, " ")
      .split
      .reject { |token| (token.length <= 2 && token !~ /\A\d+\z/) || stop_word?(token) }
  end

  def stop_word?(token)
    %w[
      a ao aos as com da das de do dos e em esta este eu o os para por qual quais que se sem sua suas seu seus um uma umas uns
      voce voces
    ].include?(token)
  end

  def fallback_suggested_replies(content)
    if content.to_s.include?("?")
      [ "Não sei informar", "Prefiro responder digitando", "Pode repetir de outra forma?" ]
    else
      [ "Entendi", "Pode explicar melhor?", "Prefiro responder digitando" ]
    end
  end

  def merge_reply_metadata(raw_response, suggested_replies)
    metadata = raw_response.is_a?(Hash) ? raw_response.deep_dup : { "raw_response" => raw_response }
    metadata["suggested_replies"] = suggested_replies
    metadata
  end

  def system_prompt(document_present: false)
    setting = TriageSetting.current
    parts = [
      setting.purpose.presence,
      setting.system_prompt,
      user_context,
      validation_flow_instruction(setting),
      reply_format_instruction
    ]
    parts << document_instruction if document_present
    parts.compact.join("\n\n")
  end

  # O prompt do admin costuma dizer "aguarde a validação da equipe" no
  # encerramento. Quando o fluxo configurado é outro (sem validação, ou com
  # check-in presencial), isso seria mentira para o solicitante — então
  # descrevemos o fluxo real, acima do prompt do admin.
  def validation_flow_instruction(setting)
    return nil if setting.require_staff_validation? && !setting.require_checkin?

    next_step = if setting.require_checkin?
      after_checkin = setting.require_staff_validation? ? "passa pela validação da equipe e entra" : "entra"
      "O solicitante pode estar fazendo a triagem de casa. No encerramento, diga que ele deve vir até o " \
        "local e, ao chegar, fazer o CHECK-IN digitando o código de 6 dígitos exibido na TV da recepção " \
        "(ou pedir ajuda à recepção) — só depois do check-in ele #{after_checkin} na fila. Se a sua " \
        "classificação preliminar indicar EMERGÊNCIA, encerre a triagem na mesma mensagem e NÃO peça check-in: " \
        "nesse caso a triagem já segue direto para a equipe#{setting.require_staff_validation? ? ' validar com prioridade' : ' e entra na fila'}. " \
        "Diga isso ao solicitante e oriente que vá imediatamente à recepção deste local (ou, se já estiver aqui, " \
        "que avise agora qualquer pessoa da equipe) dizendo que é uma emergência. Nunca o direcione para outro " \
        "hospital, pronto-socorro ou serviço: o atendimento é feito aqui."
    else
      "Neste atendimento NÃO existe validação pela equipe: assim que você encerrar, o solicitante entra " \
        "direto na fila. No encerramento, NÃO diga para aguardar validação — diga apenas que ele já está na " \
        "fila e deve aguardar ser chamado."
    end

    <<~INSTRUCTION
      ## FLUXO APÓS A TRIAGEM
      #{next_step}
      Esta regra prevalece sobre qualquer instrução anterior em contrário.
    INSTRUCTION
  end

  def reply_format_instruction
    <<~INSTRUCTION
      ## FORMATO DA RESPOSTA
      Responda sempre em JSON válido, sem markdown e sem texto fora do JSON, usando exatamente esta estrutura:
      {
        "content": "sua resposta para o usuário em linguagem natural",
        "suggested_replies": ["sugestão 1", "sugestão 2", "sugestão 3"],
        "finished": false
      }

      Regras para suggested_replies:
      - Gere de 2 a 4 respostas curtas que o usuário poderia tocar para continuar a conversa.
      - As sugestões devem servir para o contexto atual da sua própria pergunta ou orientação.
      - Cada sugestão deve parecer uma RESPOSTA do usuário, não um rótulo de campo e nem uma repetição da pergunta.
      - Nunca devolva fragmentos como "curso e semestre", "nome completo", "telefone" ou qualquer outro texto que apenas repita o que foi pedido.
      - Evite opções genéricas quando houver contexto suficiente.
      - Não repita sugestões.
      - Se a melhor continuação exigir texto livre, ainda assim ofereça respostas curtas úteis como "Posso detalhar", "Não sei informar" ou equivalentes contextuais.

      Regras para o campo finished (booleano, obrigatório em toda resposta):
      - Marque finished como true SOMENTE na mensagem que encerra a triagem — aquela que informa a
        classificação de risco preliminar e orienta o paciente sobre o próximo passo (aguardar a
        chamada pela fila).
      - Em qualquer outra mensagem (perguntas, esclarecimentos, agradecimentos intermediários), finished
        deve ser false.
      - Quando finished for true, mantenha também o marcador [triagem_concluida] dentro de content, como
        reforço redundante ao campo.

      Exemplos:
      - Se a pergunta for "Qual é o seu curso e semestre atual?", sugestões boas seriam ["Sistemas de Informação, 5º semestre", "Administração, 2º semestre", "Prefiro responder digitando"].
      - Se a pergunta for "Há quanto tempo está com a dor?", sugestões boas seriam ["Começou hoje", "Há 2 dias", "Há mais de uma semana"].
    INSTRUCTION
  end

  def document_instruction
    <<~INSTRUCTION
      ## INSTRUÇÃO SOBRE DOCUMENTO ANEXADO
      O usuário anexou um documento a esta mensagem.
      Você DEVE ler e utilizar as informações contidas nele para conduzir a triagem.
      O conteúdo do documento está incluído na mensagem do usuário, entre os marcadores "---DOCUMENTO ANEXADO---" e "---FIM DO DOCUMENTO---".
      Extraia os dados relevantes (sintomas, diagnósticos, exames, histórico) e use-os para:
      - Evitar perguntar informações que já constam no documento.
      - Fazer perguntas complementares sobre pontos ainda não esclarecidos.
      - Concluir a triagem com mais precisão.
      Não ignore o documento. Não diga que não pode analisar documentos.
    INSTRUCTION
  end

  def user_context
    user = @session.user
    lines = [ "## DADOS JÁ CADASTRADOS DO USUÁRIO (não solicite novamente):" ]
    lines << "- Nome: #{user.name}" if user.name.present?
    lines << "- CPF: #{user.cpf}" if user.cpf.present?
    lines << "- E-mail: #{user.email}" if user.email.present?
    lines << "- Telefone: #{user.phone}" if user.phone.present?
    lines << "- Data de nascimento: #{user.birth_date.strftime('%d/%m/%Y')}" if user.birth_date.present?
    lines << "- Idade: #{user.age} anos" if user.age.present?

    reasons = user.priority_reasons.map { |r| User::PRIORITY_REASON_LABELS[r] }
    if reasons.any?
      lines << "- Condições de prioridade declaradas no cadastro: #{reasons.join(', ')}"
      lines << "  (use essas condições como contexto clínico relevante; não pergunte se elas se aplicam)"
    end

    lines << first_reply_instruction if first_reply?
    lines.join("\n")
  end

  def first_reply?
    @session.chat_messages.where(sender: :ai).none?
  end

  def first_reply_instruction
    <<~INSTRUCTION.strip

      ## PRIMEIRA RESPOSTA DO CHAT
      Esta é a sua primeira mensagem para o paciente. Comece cumprimentando-o pelo primeiro nome e faça um resumo MUITO breve (1 a 2 frases) do que você já sabe pelo cadastro (idade e TODAS as condições de prioridade listadas, se houver), deixando claro que não precisa repetir essas informações. Em seguida, na mesma mensagem, faça a sua primeira pergunta de triagem.
    INSTRUCTION
  end

  def strip_marker(content)
    content.gsub(/\[triagem_concluida\]/i, "").strip
  end

  def build_messages(user_message, document_context: nil)
    history = @session.chat_messages.map do |msg|
      { role: msg.user? ? "user" : "assistant", content: msg.content }
    end

    last_user_content = build_user_content(user_message, document_context)
    history << { role: "user", content: last_user_content }
    history
  end

  # Builds the content for the last user turn, optionally including a document.
  def build_user_content(user_message, document_context)
    return user_message if document_context.nil?

    case document_context[:type]
    when :text
      "#{user_message}\n\n---DOCUMENTO ANEXADO---\n#{document_context[:text]}\n---FIM DO DOCUMENTO---"
    when :image
      case provider
      when :openai
        [
          { type: "text", text: user_message },
          { type: "image_url", image_url: { url: "data:#{document_context[:content_type]};base64,#{document_context[:base64]}", detail: "high" } }
        ]
      when :anthropic
        [
          { type: "image", source: { type: "base64", media_type: document_context[:content_type], data: document_context[:base64] } },
          { type: "text", text: user_message }
        ]
      end
    else
      user_message
    end
  end

  def build_classification_messages
    transcript = @session.chat_messages.map do |msg|
      "#{msg.user? ? 'Solicitante' : 'IA'}: #{msg.content}"
    end.join("\n")

    [ { role: "user", content: "Transcrição da triagem:\n#{transcript}" } ]
  end

  # A IA sinaliza o fim da triagem de duas formas redundantes: o campo
  # estruturado "finished" no JSON (principal — modelos seguem campos de
  # schema de forma bem mais confiável que um marcador solto no meio do
  # texto) e o marcador [triagem_concluida] embutido no content (fallback,
  # para o caso raro do modelo esquecer o campo mas ainda assim encerrar).
  def triage_finished?(content, finished_field:)
    finished_field || content.downcase.include?("[triagem_concluida]")
  end

  def classification_system_prompt
    setting = TriageSetting.current
    levels = setting.urgency_levels.map { |level| "#{level['key']} (#{level['label']}, prioridade=#{level['weight']})" }.join(", ")
    context_hint = setting.purpose.presence || "triagem geral"

    <<~PROMPT
      Você é um sistema de classificação de triagem. O contexto desta triagem é: #{context_hint}.
      Com base na transcrição fornecida, retorne um JSON com exatamente estes campos:
      {
        "urgency_level": "uma chave válida da configuração",
        "protocol_reference": "referência ou categoria interna usada para este tipo de solicitação (pode ser vazio)",
        "summary": "resumo objetivo da solicitação em 1-2 frases",
        "identified_symptoms": ["ponto-chave-1", "ponto-chave-2"],
        "ai_suggestion": "ação sugerida para o atendente",
        "classification_reasoning": "justificativa detalhada para o nível de prioridade escolhido",
        "routing_suggestion": "setor ou fila de destino recomendada",
        "confidence_score": 85.0
      }
      Nota: o campo "identified_symptoms" deve listar os principais tópicos ou pontos identificados na conversa
      (ex: para secretaria acadêmica, pode ser "matrícula inicial", "curso de Sistemas de Informação";
      para saúde, pode ser "dor abdominal", "febre há 2 dias").
      Níveis de prioridade válidos: #{levels}
      Regra: prioridade 1 = mais urgente, #{setting.urgency_levels.size} = menos urgente.
      Escolha urgency_level respeitando essa escala.
      Retorne apenas o JSON, sem texto adicional.
    PROMPT
  end
end
