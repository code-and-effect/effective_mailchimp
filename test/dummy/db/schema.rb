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

ActiveRecord::Schema[7.0].define(version: 101) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
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
    t.string "checksum", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "email_templates", force: :cascade do |t|
    t.string "template_name"
    t.string "subject"
    t.string "from"
    t.string "bcc"
    t.string "cc"
    t.string "content_type"
    t.text "body"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "mailchimp_categories", force: :cascade do |t|
    t.integer "mailchimp_list_id"
    t.string "mailchimp_id"
    t.string "list_id"
    t.string "name"
    t.string "list_name"
    t.string "display_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mailchimp_interests", force: :cascade do |t|
    t.integer "mailchimp_list_id"
    t.integer "mailchimp_category_id"
    t.string "mailchimp_id"
    t.string "list_id"
    t.string "category_id"
    t.string "name"
    t.string "list_name"
    t.string "category_name"
    t.integer "display_order"
    t.integer "subscriber_count"
    t.boolean "can_subscribe"
    t.boolean "force_subscribe"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mailchimp_list_members", force: :cascade do |t|
    t.integer "user_id"
    t.string "user_type"
    t.integer "mailchimp_list_id"
    t.string "mailchimp_id"
    t.string "web_id"
    t.string "email_address"
    t.string "full_name"
    t.boolean "subscribed", default: false
    t.boolean "cannot_be_subscribed", default: false
    t.text "interests"
    t.datetime "last_synced_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mailchimp_lists", force: :cascade do |t|
    t.string "mailchimp_id"
    t.string "web_id"
    t.string "name"
    t.boolean "can_subscribe"
    t.boolean "force_subscribe"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.string "email", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "roles_mask"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
