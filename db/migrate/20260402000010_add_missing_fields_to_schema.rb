class AddMissingFieldsToSchema < ActiveRecord::Migration[8.0]
  def change
    # ticket_number: the unique alphanumeric ticket shown to the patient (e.g. SYZ99G5JC)
    add_column :queue_entries, :ticket_number, :string, null: false, default: ""
    add_index :queue_entries, :ticket_number, unique: true

    # clinical_reasoning: AI explainability text shown to nursing and doctor
    add_column :ai_classifications, :clinical_reasoning, :text

    # specialty_suggestion: specialty recommended by the AI (e.g. "Clínico Geral")
    add_column :ai_classifications, :specialty_suggestion, :string

    # doctor: boolean flag for users who access the doctor view
    add_column :users, :doctor, :boolean, null: false, default: false
    add_index :users, :doctor
  end
end
