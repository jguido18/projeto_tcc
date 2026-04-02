class CreateQueueEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :queue_entries do |t|
      t.references :triage_session, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :establishment, null: false, foreign_key: { on_delete: :restrict }
      t.string :urgency_level, null: false
      t.integer :urgency_weight, null: false  # red=1, orange=2, yellow=3, green=4, blue=5
      t.string :status, null: false, default: "waiting"
      # Statuses: waiting, called, in_attendance, left, completed
      t.datetime :queued_at, null: false
      t.datetime :called_at
      t.datetime :service_started_at
      t.datetime :service_finished_at

      t.timestamps
    end

    add_index :queue_entries, [ :establishment_id, :status ]
    add_index :queue_entries, [ :urgency_weight, :queued_at ]
  end
end
