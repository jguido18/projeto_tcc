require "net/http"
require "json"

# Envia uma Notification por SMS via textbee (https://textbee.dev) — usa um
# celular Android real (com chip/plano normal) como gateway, via API deles.
# Não levanta exceção em caso de falha/config ausente — apenas registra em log
# e retorna false, para nunca quebrar o fluxo do colaborador que chamou o
# paciente.
#
# Por que textbee e não Twilio: contas trial do Twilio (WhatsApp e SMS) só
# aceitam mensagens de templates pré-aprovados, não texto livre customizado —
# ver histórico no README. O textbee manda o SMS como o próprio celular
# mandaria manualmente, sem essa restrição.
class SmsNotifierService
  API_BASE = "https://api.textbee.dev/api/v1".freeze

  def initialize(notification)
    @notification = notification
  end

  # Retorna true se a mensagem foi efetivamente enviada pela API do textbee.
  def deliver
    user = @notification.user

    return skip("paciente sem telefone cadastrado") if user.phone.blank?
    return skip("credencial do textbee (TEXTBEE_API_KEY) não configurada") unless configured?

    send_via_textbee(user.phone)
  end

  private

  def configured?
    api_key.present?
  end

  def send_via_textbee(phone)
    uri = URI("#{API_BASE}/gateway/send-sms")

    target_phone = force_recipient.presence || normalized_phone(phone)
    if force_recipient.present?
      Rails.logger.info("[SmsNotifierService] Modo de teste: destinatário forçado para #{force_recipient} (paciente real seria #{normalized_phone(phone)})")
    end

    payload = { recipients: [ target_phone ], message: message_body }
    payload[:deviceId] = device_id if device_id.present?

    request = Net::HTTP::Post.new(uri)
    request["x-api-key"]    = api_key
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info("[SmsNotifierService] Enviado — notification_id=#{@notification.id}")
      true
    else
      Rails.logger.error("[SmsNotifierService] Falha (#{response.code}) — notification_id=#{@notification.id}: #{response.body}")
      false
    end
  rescue => e
    Rails.logger.error("[SmsNotifierService] Erro — notification_id=#{@notification.id}: #{e.class} - #{e.message}")
    false
  end

  def message_body
    "#{@notification.title} — #{@notification.body}"
  end

  # Normalização simples para números brasileiros: mantém dígitos e garante o
  # código do país (+55) quando o paciente cadastrou só DDD + número.
  def normalized_phone(phone)
    return phone if phone.to_s.start_with?("+")

    digits = phone.to_s.gsub(/\D/, "")
    digits = digits.delete_prefix("55") if digits.length > 11
    "+55#{digits}"
  end

  def skip(reason)
    Rails.logger.info(
      "[SmsNotifierService] Simulando envio (#{reason}): " \
      "\"#{@notification.title} — #{@notification.body}\" para #{@notification.user.name}"
    )
    false
  end

  def api_key   = ENV["TEXTBEE_API_KEY"]   || Rails.application.credentials.textbee_api_key
  def device_id = ENV["TEXTBEE_DEVICE_ID"] || Rails.application.credentials.textbee_device_id

  # Modo de teste/demonstração: quando configurado, TODO SMS vai pra esse
  # número em vez do telefone real do paciente — útil pra validar o fluxo
  # inteiro só com o celular vinculado ao textbee, sem depender de números
  # reais de pacientes. Deixe a variável vazia/ausente para produção normal.
  def force_recipient
    ENV["SMS_FORCE_RECIPIENT"]
  end
end
