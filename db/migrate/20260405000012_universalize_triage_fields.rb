class UniversalizeTriageFields < ActiveRecord::Migration[8.1]
  def change
    rename_column :triage_sessions, :chief_complaint, :initial_demand

    rename_column :ai_classifications, :manchester_code, :protocol_reference
    rename_column :ai_classifications, :clinical_reasoning, :classification_reasoning
    rename_column :ai_classifications, :specialty_suggestion, :routing_suggestion
  end
end
