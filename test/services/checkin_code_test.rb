require "test_helper"

class CheckinCodeTest < ActiveSupport::TestCase
  test "current code has 6 digits" do
    assert_match(/\A\d{6}\z/, CheckinCode.current)
  end

  test "the code shown now is accepted" do
    assert CheckinCode.valid?(CheckinCode.current)
  end

  test "accepts formatting like spaces (\"123 456\")" do
    code = CheckinCode.current
    assert CheckinCode.valid?("#{code[0, 3]} #{code[3, 3]}")
  end

  test "a code read a minute ago is still accepted (grace for slow typing/login)" do
    code = CheckinCode.current(at: 1.minute.ago)

    assert CheckinCode.valid?(code)
  end

  test "an old code (e.g. a photo shared on WhatsApp) is rejected" do
    code = CheckinCode.current(at: 10.minutes.ago)

    assert_not CheckinCode.valid?(code)
  end

  test "garbage input is rejected" do
    assert_not CheckinCode.valid?(nil)
    assert_not CheckinCode.valid?("12345")
    assert_not CheckinCode.valid?("abcdef")
  end

  test "the code changes from one minute to the next" do
    now = Time.zone.parse("2026-10-08 10:00:30")

    assert_not_equal CheckinCode.current(at: now), CheckinCode.current(at: now + 1.minute)
  end
end
