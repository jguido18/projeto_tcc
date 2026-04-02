class CreateTriageSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :triage_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :establishment, null: false, foreign_key: { on_delete: :restrict }
      t.string :status, null: false, default: "in_triage"
      # Statuses: in_triage, awaiting_validation, validated, in_queue, in_attendance, completed, cancelled
      t.text :chief_complaint
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.jsonb :ai_metadata

      t.timestamps
    end

    add_index :triage_sessions, :status
    add_index :triage_sessions, [ :user_id, :status ]
    add_index :triage_sessions, [ :establishment_id, :status ]
  end
end
