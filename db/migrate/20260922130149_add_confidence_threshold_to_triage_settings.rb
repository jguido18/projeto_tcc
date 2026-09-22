class AddConfidenceThresholdToTriageSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :triage_settings, :confidence_threshold, :integer, default: 70, null: false
  end
end
