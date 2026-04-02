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

ActiveRecord::Schema[8.1].define(version: 2026_04_02_000010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_classifications", force: :cascade do |t|
    t.string "ai_model", null: false
    t.text "ai_suggestion"
    t.text "clinical_reasoning"
    t.decimal "confidence_score", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.jsonb "identified_symptoms", default: [], null: false
    t.string "manchester_code"
    t.string "specialty_suggestion"
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

  create_table "establishments", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.string "cnpj"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.string "phone"
    t.jsonb "settings"
    t.text "system_prompt", null: false
    t.datetime "updated_at", null: false
    t.string "urgency_protocol", default: "manchester", null: false
    t.index ["active"], name: "index_establishments_on_active"
    t.index ["cnpj"], name: "index_establishments_on_cnpj", unique: true, where: "(cnpj IS NOT NULL)"
    t.index ["kind"], name: "index_establishments_on_kind"
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
    t.bigint "establishment_id", null: false
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
    t.index ["establishment_id", "status"], name: "index_queue_entries_on_establishment_id_and_status"
    t.index ["establishment_id"], name: "index_queue_entries_on_establishment_id"
    t.index ["ticket_number"], name: "index_queue_entries_on_ticket_number", unique: true
    t.index ["triage_session_id"], name: "index_queue_entries_on_triage_session_id", unique: true
    t.index ["urgency_weight", "queued_at"], name: "index_queue_entries_on_urgency_weight_and_queued_at"
    t.index ["user_id"], name: "index_queue_entries_on_user_id"
  end

  create_table "triage_sessions", force: :cascade do |t|
    t.jsonb "ai_metadata"
    t.text "chief_complaint"
    t.datetime "created_at", null: false
    t.bigint "establishment_id", null: false
    t.datetime "finished_at"
    t.datetime "started_at", null: false
    t.string "status", default: "in_triage", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["establishment_id", "status"], name: "index_triage_sessions_on_establishment_id_and_status"
    t.index ["establishment_id"], name: "index_triage_sessions_on_establishment_id"
    t.index ["status"], name: "index_triage_sessions_on_status"
    t.index ["user_id", "status"], name: "index_triage_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_triage_sessions_on_user_id"
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
    t.boolean "attendant", default: false, null: false
    t.date "birth_date"
    t.string "cpf"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.boolean "doctor", default: false, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.bigint "establishment_id", null: false
    t.string "job_title"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "name", null: false
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["attendant"], name: "index_users_on_attendant"
    t.index ["cpf"], name: "index_users_on_cpf", unique: true, where: "(cpf IS NOT NULL)"
    t.index ["doctor"], name: "index_users_on_doctor"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["establishment_id"], name: "index_users_on_establishment_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "ai_classifications", "triage_sessions", on_delete: :cascade
  add_foreign_key "chat_messages", "triage_sessions", on_delete: :cascade
  add_foreign_key "notifications", "triage_sessions", on_delete: :nullify
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "queue_entries", "establishments", on_delete: :restrict
  add_foreign_key "queue_entries", "triage_sessions", on_delete: :restrict
  add_foreign_key "queue_entries", "users", on_delete: :restrict
  add_foreign_key "triage_sessions", "establishments", on_delete: :restrict
  add_foreign_key "triage_sessions", "users", on_delete: :restrict
  add_foreign_key "triage_validations", "ai_classifications", on_delete: :restrict
  add_foreign_key "triage_validations", "users", on_delete: :restrict
  add_foreign_key "users", "establishments", on_delete: :restrict
end
