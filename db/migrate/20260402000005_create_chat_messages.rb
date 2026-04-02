class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.references :triage_session, null: false, foreign_key: { on_delete: :cascade }
      t.string :sender, null: false  # user, ai
      t.text :content, null: false
      t.jsonb :ai_raw_response
      t.integer :sequence, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end

    add_index :chat_messages, [ :triage_session_id, :sequence ]
  end
end
