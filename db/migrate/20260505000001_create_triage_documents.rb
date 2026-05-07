class CreateTriageDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :triage_documents do |t|
      t.references :triage_session, null: false, foreign_key: { on_delete: :cascade }
      t.references :chat_message,   null: true,  foreign_key: { on_delete: :nullify }

      t.string :original_filename
      t.string :content_type
      t.string :document_type,       default: "desconhecido"
      t.string :validation_status,   default: "pending", null: false
      t.jsonb  :validation_result,   default: {}
      t.text   :extracted_text

      t.timestamps
    end

    add_index :triage_documents, :validation_status
  end
end
