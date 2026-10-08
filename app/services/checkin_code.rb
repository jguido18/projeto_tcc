require "openssl"

# Código de check-in presencial, exibido só na TV da recepção. Muda a cada
# WINDOW_SECONDS — mesmo princípio do TOTP (o código de autenticação em dois
# fatores): é derivado do minuto atual + uma chave secreta do servidor, então
# não precisa ser guardado em lugar nenhum, e uma foto do código mandada pelo
# WhatsApp expira antes de ser útil para alguém que não está no local.
class CheckinCode
  WINDOW_SECONDS = 60
  DIGITS = 6
  # Aceita também as janelas anteriores, para cobrir quem leu o código no último
  # segundo, demorou digitando ou precisou fazer login antes (~3 min no total).
  GRACE_WINDOWS = 2

  def self.current(at: Time.current)
    for_window(window_for(at))
  end

  def self.valid?(code, at: Time.current)
    normalized = code.to_s.gsub(/\D/, "")
    return false unless normalized.length == DIGITS

    window = window_for(at)
    (0..GRACE_WINDOWS).any? do |offset|
      ActiveSupport::SecurityUtils.secure_compare(normalized, for_window(window - offset))
    end
  end

  # Segundos até o código atual trocar — usado pela TV para se atualizar.
  def self.seconds_remaining(at: Time.current)
    WINDOW_SECONDS - (at.to_i % WINDOW_SECONDS)
  end

  def self.window_for(time)
    time.to_i / WINDOW_SECONDS
  end

  def self.for_window(window)
    digest = OpenSSL::HMAC.digest("SHA256", secret, window.to_s)
    (digest.unpack1("N") % (10**DIGITS)).to_s.rjust(DIGITS, "0")
  end

  def self.secret
    Rails.application.key_generator.generate_key("triage-checkin-code", 32)
  end

  private_class_method :window_for, :for_window, :secret
end
