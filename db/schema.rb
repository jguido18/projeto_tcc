# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_05_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_classifications", force: :cascade do |t|
    t.string "ai_model", null: false
    t.text "ai_suggestion"
    t.text "classification_reasoning"
    t.decimal "confidence_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.jsonb "identified_symptoms", default: [], null: false
    t.string "protocol_reference"
    t.string "routing_suggestion"
    t.text "summary", null: false
    t.bigint "triage_session_id", null: false
    t.datetime "updated_at", null: false
    t.string "urgency_level", null: false
    t.index ["triage_session_id"], name: "index_ai_classifications_on_triage_session_id", unique: true
    t.index ["urgency_level"], name: "index_ai_classifications_on_urgency_level"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.jsonb "ai_raw_response"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "sender", null: false
    t.datetime "sent_at", null: false
    t.integer "sequence", null: false
    t.bigint "triage_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["triage_session_id", "sequence"], name: "index_chat_messages_on_triage_session_id_and_sequence"
    t.index ["triage_session_id"], name: "index_chat_messages_on_triage_session_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body", null: false
    t.string "channel", default: "websocket", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.bigint "triage_session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["triage_session_id"], name: "index_notifications_on_triage_session_id"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "queue_entries", force: :cascade do |t|
    t.datetime "called_at"
    t.datetime "created_at", null: false
    t.datetime "queued_at", null: false
    t.datetime "service_finished_at"
    t.datetime "service_started_at"
    t.string "status", default: "waiting", null: false
    t.string "ticket_number", default: "", null: false
    t.bigint "triage_session_id", null: false
    t.datetime "updated_at", null: false
    t.string "urgency_level", null: false
    t.integer "urgency_weight", null: false
    t.bigint "user_id", null: false
    t.index ["ticket_number"], name: "index_queue_entries_on_ticket_number", unique: true
    t.index ["triage_session_id"], name: "index_queue_entries_on_triage_session_id", unique: true
    t.index ["urgency_weight", "queued_at"], name: "index_queue_entries_on_urgency_weight_and_queued_at"
    t.index ["user_id"], name: "index_queue_entries_on_user_id"
  end

  create_table "triage_documents", force: :cascade do |t|
    t.bigint "chat_message_id"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "document_type", default: "desconhecido"
    t.text "extracted_text"
    t.string "original_filename"
    t.bigint "triage_session_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_result", default: {}
    t.string "validation_status", default: "pending", null: false
    t.index ["chat_message_id"], name: "index_triage_documents_on_chat_message_id"
    t.index ["triage_session_id"], name: "index_triage_documents_on_triage_session_id"
    t.index ["validation_status"], name: "index_triage_documents_on_validation_status"
  end

  create_table "triage_sessions", force: :cascade do |t|
    t.jsonb "ai_metadata"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.text "initial_demand"
    t.datetime "started_at", null: false
    t.string "status", default: "in_triage", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_triage_sessions_on_status"
    t.index ["user_id", "status"], name: "index_triage_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_triage_sessions_on_user_id"
  end

  create_table "triage_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hint_example"
    t.text "purpose"
    t.text "system_prompt", null: false
    t.datetime "updated_at", null: false
    t.jsonb "urgency_levels", default: [], null: false
    t.index ["created_at"], name: "index_triage_settings_on_created_at"
  end

  create_table "triage_validations", force: :cascade do |t|
    t.bigint "ai_classification_id", null: false
    t.datetime "created_at", null: false
    t.string "decision", null: false
    t.string "final_urgency_level", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "validated_at", null: false
    t.index ["ai_classification_id"], name: "index_triage_validations_on_ai_classification_id", unique: true
    t.index ["decision"], name: "index_triage_validations_on_decision"
    t.index ["user_id"], name: "index_triage_validations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "admin", default: false, null: false
    t.date "birth_date"
    t.boolean "colaborador", default: false, null: false
    t.string "cpf"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "job_title"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "name", null: false
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.boolean "specialist", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["colaborador"], name: "index_users_on_colaborador"
    t.index ["cpf"], name: "index_users_on_cpf", unique: true, where: "(cpf IS NOT NULL)"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["specialist"], name: "index_users_on_specialist"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_classifications", "triage_sessions", on_delete: :cascade
  add_foreign_key "chat_messages", "triage_sessions", on_delete: :cascade
  add_foreign_key "notifications", "triage_sessions", on_delete: :nullify
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "queue_entries", "triage_sessions", on_delete: :restrict
  add_foreign_key "queue_entries", "users", on_delete: :restrict
  add_foreign_key "triage_documents", "chat_messages", on_delete: :nullify
  add_foreign_key "triage_documents", "triage_sessions", on_delete: :cascade
  add_foreign_key "triage_sessions", "users", on_delete: :restrict
  add_foreign_key "triage_validations", "ai_classifications", on_delete: :restrict
  add_foreign_key "triage_validations", "users", on_delete: :restrict
end
