class CreateTriageValidations < ActiveRecord::Migration[8.0]
  def change
    create_table :triage_validations do |t|
      t.references :ai_classification, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.string :decision, null: false  # confirmed, adjusted, rejected
      t.string :final_urgency_level, null: false
      t.text :notes
      t.datetime :validated_at, null: false

      t.timestamps
    end

    add_index :triage_validations, :decision
  end
end
