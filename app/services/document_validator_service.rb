class DocumentValidatorService
  VALIDATION_PROMPT = <<~PROMPT.freeze
    Você é um especialista em verificação de documentos brasileiros.
    Analise a imagem fornecida e retorne APENAS um JSON com a estrutura abaixo.

    Documentos que você deve reconhecer: RG, CPF, CNH, Passaporte, Comprovante de residência/endereço.

    Critérios de autenticidade a verificar:
    - Layout e formatação típicos do documento brasileiro
    - Presença de campos obrigatórios (nome, número, data)
    - Ausência de sinais óbvios de adulteração (cortes, sobreposições suspeitas, fontes inconsistentes)
    - Qualidade mínima de legibilidade

    IMPORTANTE: Você NÃO deve afirmar com certeza absoluta que um documento é autêntico ou falso.
    Use o campo confidence_score para indicar sua certeza (0-100).
    Se a imagem não for um documento, marque is_document como false.

    Retorne APENAS este JSON (sem texto adicional):
    {
      "is_document": true,
      "document_type": "rg",
      "authenticity_assessment": "valid",
      "confidence_score": 85,
      "extracted_data": {
        "name": "Nome extraído ou null",
        "document_number": "Número extraído ou null",
        "birth_date": "Data no formato DD/MM/AAAA ou null",
        "issuing_state": "UF ou null",
        "expiry_date": "Data ou null"
      },
      "issues_found": [],
      "summary": "Resumo da análise em 1 frase"
    }

    Valores válidos para document_type: rg, cpf, cnh, passaporte, comprovante, outro
    Valores válidos para authenticity_assessment: valid, invalid, uncertain
    Se is_document for false, retorne todos os outros campos como null.
  PROMPT

  def initialize(triage_document)
    @document = triage_document
  end

  # Validates the document using AI vision. Updates the TriageDocument record.
  # Returns the validation result hash.
  def validate
    unless @document.image?
      @document.update!(validation_status: :skipped, validation_result: { reason: "Validação disponível apenas para imagens" })
      return @document.validation_result
    end

    result = call_vision_api
    status = map_status(result["authenticity_assessment"], result["is_document"])

    @document.update!(
      document_type:     result["document_type"].presence || "desconhecido",
      validation_status: status,
      validation_result: result
    )

    result
  rescue => e
    Rails.logger.error("[DocumentValidatorService] Error: #{e.class} - #{e.message}")
    @document.update!(
      validation_status: :uncertain,
      validation_result: { error: e.message, summary: "Não foi possível validar o documento automaticamente." }
    )
    @document.validation_result
  end

  private

  def call_vision_api
    raw = @document.file.download
    base64 = Base64.strict_encode64(raw)
    content_type = @document.content_type

    case provider
    when :openai    then call_openai(base64, content_type)
    when :anthropic then call_anthropic(base64, content_type)
    end
  end

  def call_openai(base64, content_type)
    require "openai"
    client = OpenAI::Client.new(access_token: openai_key)
    response = client.chat(
      parameters: {
        model:           openai_model,
        max_tokens:      512,
        temperature:     0.0,
        response_format: { type: "json_object" },
        messages: [
          {
            role:    "user",
            content: [
              { type: "text",      text: VALIDATION_PROMPT },
              { type: "image_url", image_url: { url: "data:#{content_type};base64,#{base64}", detail: "high" } }
            ]
          }
        ]
      }
    )
    JSON.parse(response.dig("choices", 0, "message", "content").to_s)
  end

  def call_anthropic(base64, content_type)
    client = Anthropic::Client.new(api_key: anthropic_key)
    response = client.messages.create(
      model:      anthropic_model,
      max_tokens: 512,
      messages: [
        {
          role:    "user",
          content: [
            { type: "image", source: { type: "base64", media_type: content_type, data: base64 } },
            { type: "text",  text: VALIDATION_PROMPT }
          ]
        }
      ]
    )
    raw = response.content.first.text.to_s.strip
    json_match = raw.match(/\{.*\}/m)
    JSON.parse(json_match ? json_match[0] : raw)
  end

  def map_status(assessment, is_document)
    return :invalid unless is_document
    case assessment
    when "valid"     then :valid
    when "invalid"   then :invalid
    else                  :uncertain
    end
  end

  def provider
    @provider ||= begin
      configured = ENV["AI_PROVIDER"].to_s.strip.downcase
      if configured == "openai"        then :openai
      elsif configured == "anthropic"  then :anthropic
      elsif openai_key.present?        then :openai
      elsif anthropic_key.present?     then :anthropic
      else raise "Configure OPENAI_API_KEY ou ANTHROPIC_API_KEY."
      end
    end
  end

  def openai_key    = ENV["OPENAI_API_KEY"]    || Rails.application.credentials.openai_api_key
  def anthropic_key = ENV["ANTHROPIC_API_KEY"] || Rails.application.credentials.anthropic_api_key
  def openai_model    = ENV["OPENAI_MODEL"].presence    || "gpt-4o-mini"
  def anthropic_model = ENV["ANTHROPIC_MODEL"].presence || "claude-opus-4-6"
end
