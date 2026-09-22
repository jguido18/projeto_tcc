require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "phone is required when sms_notifications_enabled is true" do
    user = build_patient(phone: nil, sms_notifications_enabled: true)

    assert_not user.valid?
    assert_includes user.errors[:phone], "é obrigatório para ativar o aviso por SMS"
  end

  test "phone is not required when sms_notifications_enabled is false" do
    user = build_patient(phone: nil, sms_notifications_enabled: false)

    assert user.valid?
  end

  test "phone present satisfies the requirement when sms_notifications_enabled is true" do
    user = build_patient(phone: "11999998888", sms_notifications_enabled: true)

    assert user.valid?
  end

  test "bmi is nil when height or weight is missing" do
    assert_nil build_patient(height_cm: nil, weight_kg: 90).bmi
    assert_nil build_patient(height_cm: 180, weight_kg: nil).bmi
  end

  test "bmi is computed from height (cm) and weight (kg)" do
    user = build_patient(height_cm: 180, weight_kg: 97.2)

    assert_equal 30.0, user.bmi
  end

  test "obeso? is true when the computed bmi reaches the obesity threshold, without any manual flag" do
    obese = build_patient(height_cm: 170, weight_kg: 90)   # IMC ~31.1
    not_obese = build_patient(height_cm: 170, weight_kg: 65) # IMC ~22.5

    assert obese.obeso?
    assert_not not_obese.obeso?
  end

  test "obeso? is false when height/weight are missing, instead of guessing" do
    assert_not build_patient(height_cm: nil, weight_kg: nil).obeso?
  end

  private

  def build_patient(phone: nil, sms_notifications_enabled: false, height_cm: nil, weight_kg: nil)
    User.new(
      name: "Paciente Teste",
      email: "paciente-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      cpf: SecureRandom.hex(6),
      phone: phone,
      sms_notifications_enabled: sms_notifications_enabled,
      height_cm: height_cm,
      weight_kg: weight_kg
    )
  end
end
