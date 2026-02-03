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

ActiveRecord::Schema[8.0].define(version: 2026_02_03_190034) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "applications", force: :cascade do |t|
    t.string "fullname"
    t.text "address"
    t.text "email"
    t.text "phone"
    t.bigint "career_id", null: false
    t.string "emplyment"
    t.text "cv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["career_id"], name: "index_applications_on_career_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "auditable_type", null: false
    t.integer "auditable_id", null: false
    t.text "change_data"
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "request_method"
    t.string "request_path"
    t.string "controller_name"
    t.string "action_name"
    t.text "params_data"
    t.text "changes_summary"
    t.text "description"
    t.string "referer"
    t.integer "duration_ms"
    t.integer "status_code"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["action_name"], name: "index_audit_logs_on_action_name"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["controller_name"], name: "index_audit_logs_on_controller_name"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["request_method"], name: "index_audit_logs_on_request_method"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "careers", force: :cascade do |t|
    t.bigint "profession_id", null: false
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profession_id"], name: "index_careers_on_profession_id"
  end

  create_table "facts", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", default: ""
    t.string "modified_by"
    t.string "created_by"
    t.string "custom_width", default: "f"
  end

  create_table "job_postings", force: :cascade do |t|
    t.string "name"
    t.date "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "medical_services", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.bigint "specialty_id"
    t.bigint "member_id"
    t.boolean "has_day_hospitalization", default: false
    t.index ["member_id"], name: "index_medical_services_on_member_id"
    t.index ["specialty_id"], name: "index_medical_services_on_specialty_id"
  end

  create_table "medicines_consumptions", force: :cascade do |t|
    t.string "month", null: false
    t.integer "year", null: false
    t.decimal "consumption", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year", "month"], name: "index_medicines_consumptions_on_year_and_month", unique: true
    t.index ["year"], name: "index_medicines_consumptions_on_year"
  end

  create_table "members", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.bigint "profession_id", null: false
    t.bigint "specialty_id"
    t.string "academic_title"
    t.string "doctor_grade", default: ""
    t.boolean "has_own_page", default: false
    t.boolean "has_prices", default: false
    t.boolean "selected"
    t.integer "order"
    t.boolean "schroth"
    t.boolean "founder", default: false
    t.boolean "has_day_hospitalization", default: false
    t.boolean "is_active", default: true
    t.boolean "specialty_favored", default: false
    t.index ["profession_id"], name: "index_members_on_profession_id"
    t.index ["specialty_id"], name: "index_members_on_specialty_id"
  end

  create_table "professions", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.boolean "has_specialty", default: false
    t.integer "order"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "rating"
    t.string "author"
    t.text "content"
    t.boolean "approved", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "specialties", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.text "description"
    t.boolean "has_day_hospitalization", default: false
    t.boolean "is_day_hospitalize", default: false
    t.boolean "is_active", default: true
    t.integer "medical_services_count"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false
    t.string "alias"
    t.boolean "god_mode", default: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applications", "careers"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "careers", "professions"
  add_foreign_key "medical_services", "members"
  add_foreign_key "medical_services", "specialties"
  add_foreign_key "members", "professions"
  add_foreign_key "members", "specialties"
end
