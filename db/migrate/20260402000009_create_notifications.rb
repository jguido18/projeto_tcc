class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :triage_session, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false  # called_for_attendance, position_updated, triage_validated, cancellation
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :read, null: false, default: false
      t.datetime :read_at
      t.string :channel, null: false, default: "websocket"  # websocket, push, sms

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read ]
  end
end
