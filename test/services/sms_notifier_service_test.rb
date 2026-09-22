require "test_helper"

class SmsNotifierServiceTest < ActiveSupport::TestCase
  TEXTBEE_ENV_VARS = %w[TEXTBEE_API_KEY TEXTBEE_DEVICE_ID SMS_FORCE_RECIPIENT].freeze

  setup do
    # Neutraliza o .env do dev (que pode ter chave real, device e o modo de
    # teste ligados) para os testes ficarem isolados do ambiente local —
    # cada teste liga explicitamente só o que precisa via with_env.
    @original_textbee_env = TEXTBEE_ENV_VARS.index_with { |k| ENV.delete(k) }

    @user = User.create!(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6),
      phone: "11999998888"
    )
    @notification = Notification.create!(
      user: @user,
      kind: :called_for_attendance,
      title: "Você foi chamado",
      body: "SENHA123 — dirija-se ao ponto de atendimento",
      channel: :sms
    )
  end

  teardown do
    @original_textbee_env.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "skips delivery (without raising) when the patient has no phone" do
    @user.update!(phone: nil)

    result = SmsNotifierService.new(@notification).deliver

    assert_equal false, result
  end

  test "skips delivery (without raising) when the textbee API key is not configured" do
    with_env(TEXTBEE_API_KEY: nil) do
      result = SmsNotifierService.new(@notification).deliver

      assert_equal false, result
    end
  end

  test "returns true when textbee responds with success" do
    fake_response = Net::HTTPOK.new("1.1", "200", "OK")

    with_env(TEXTBEE_API_KEY: "tb_123") do
      with_stubbed_http_start(fake_response) do
        result = SmsNotifierService.new(@notification).deliver
        assert_equal true, result
      end
    end
  end

  test "returns false (without raising) when textbee responds with an error" do
    fake_response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    fake_response.define_singleton_method(:body) { '{"message":"invalid recipient"}' }

    with_env(TEXTBEE_API_KEY: "tb_123") do
      with_stubbed_http_start(fake_response) do
        result = SmsNotifierService.new(@notification).deliver
        assert_equal false, result
      end
    end
  end

  test "sends recipients and message as JSON, with the notification's real text" do
    fake_response = Net::HTTPOK.new("1.1", "200", "OK")

    with_env(TEXTBEE_API_KEY: "tb_123") do
      with_stubbed_http_start(fake_response) do
        captured = capture_request_body { SmsNotifierService.new(@notification).deliver }

        assert_equal [ "+5511999998888" ], captured["recipients"]
        assert_includes captured["message"], @notification.title
        assert_includes captured["message"], @notification.body
        assert_not captured.key?("deviceId")
      end
    end
  end

  test "includes deviceId in the payload only when TEXTBEE_DEVICE_ID is configured" do
    fake_response = Net::HTTPOK.new("1.1", "200", "OK")

    with_env(TEXTBEE_API_KEY: "tb_123", TEXTBEE_DEVICE_ID: "device-42") do
      with_stubbed_http_start(fake_response) do
        captured = capture_request_body { SmsNotifierService.new(@notification).deliver }

        assert_equal "device-42", captured["deviceId"]
      end
    end
  end

  test "SMS_FORCE_RECIPIENT overrides the destination, ignoring the patient's real phone" do
    fake_response = Net::HTTPOK.new("1.1", "200", "OK")

    with_env(TEXTBEE_API_KEY: "tb_123", SMS_FORCE_RECIPIENT: "+5519971662004") do
      with_stubbed_http_start(fake_response) do
        captured = capture_request_body { SmsNotifierService.new(@notification).deliver }

        assert_equal [ "+5519971662004" ], captured["recipients"]
      end
    end
  end

  test "sends to the patient's real phone when SMS_FORCE_RECIPIENT is not set" do
    fake_response = Net::HTTPOK.new("1.1", "200", "OK")

    with_env(TEXTBEE_API_KEY: "tb_123", SMS_FORCE_RECIPIENT: nil) do
      with_stubbed_http_start(fake_response) do
        captured = capture_request_body { SmsNotifierService.new(@notification).deliver }

        assert_equal [ "+5511999998888" ], captured["recipients"]
      end
    end
  end

  private

  def with_env(vars)
    original = vars.keys.index_with { |k| ENV[k.to_s] }
    vars.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
  end

  # minitest 6 removeu minitest/mock (sem Object#stub embutido), então a
  # substituição de Net::HTTP.start é feita "na mão" — troca o método de
  # classe pela resposta fake e sempre restaura o original ao final.
  def with_stubbed_http_start(fake_response)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*_args, **_kwargs| fake_response }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  # Intercepta o corpo JSON que o serviço monta, sem precisar de um mock de
  # objeto (minitest 6 não traz mais minitest/mock).
  def capture_request_body
    captured = nil
    original = Net::HTTP::Post.instance_method(:body=)
    Net::HTTP::Post.define_method(:body=) { |value| captured = JSON.parse(value) }

    yield

    captured
  ensure
    Net::HTTP::Post.define_method(:body=, original)
  end
end
