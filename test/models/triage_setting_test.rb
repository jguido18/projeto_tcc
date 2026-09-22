require "test_helper"

class TriageSettingTest < ActiveSupport::TestCase
  setup do
    TriageSetting.delete_all
  end

  test "sla_minutes_for reads the configured value for the level" do
    setting = TriageSetting.current

    assert_equal 10, setting.sla_minutes_for("red")
    assert_equal 120, setting.sla_minutes_for("green")
  end

  test "sla_minutes_for falls back to weight * 15 when the level has no sla_minutes stored" do
    setting = TriageSetting.current
    setting.update_column(
      :urgency_levels,
      [ { "key" => "red", "label" => "Emergência", "color" => "#E53E3E", "weight" => 1 } ]
    )

    assert_equal 15, setting.reload.sla_minutes_for("red")
  end

  test "confidence_threshold defaults to 70" do
    assert_equal 70, TriageSetting.current.confidence_threshold
  end
end
