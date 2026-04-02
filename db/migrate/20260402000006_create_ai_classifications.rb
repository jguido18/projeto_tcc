class CreateAiClassifications < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_classifications do |t|
      t.references :triage_session, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :urgency_level, null: false  # red, orange, yellow, green, blue
      t.string :manchester_code
      t.text :summary, null: false
      t.jsonb :identified_symptoms, null: false, default: []
      t.text :ai_suggestion
      t.decimal :confidence_score, precision: 5, scale: 2
      t.string :ai_model, null: false
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :ai_classifications, :urgency_level
  end
end
