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

ActiveRecord::Schema[7.0].define(version: 2024_06_13_193140) do
  create_table "accounts", force: :cascade do |t|
    t.string "account_identifier"
    t.string "psmain_code"
    t.string "institution"
    t.string "bsb"
    t.string "account_number"
    t.string "account_name"
    t.datetime "last_executed_at"
    t.string "last_identifier"
    t.datetime "last_time"
    t.string "first_identifier"
    t.integer "total_transactions"
    t.integer "total_transaction_value"
    t.integer "last_block_transactions"
    t.integer "last_block_value"
    t.boolean "test_account"
    t.string "consent_identifier"
    t.string "connection_identifier"
    t.datetime "consent_expires_at"
    t.string "user_identifier"
    t.string "psmain_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "outlay_auth_ciphertext"
    t.string "outlay_username"
    t.string "outlay_name"
    t.string "outlay_password_ciphertext"
    t.index ["account_identifier"], name: "index_accounts_on_account_identifier"
    t.index ["bsb", "account_number"], name: "index_accounts_on_bsb_and_account_number"
    t.index ["consent_identifier"], name: "index_accounts_on_consent_identifier"
    t.index ["psmain_code"], name: "index_accounts_on_psmain_code"
  end

  create_table "disbursements", force: :cascade do |t|
    t.integer "total_amount"
    t.integer "status"
    t.string "code"
    t.integer "account_id"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_disbursements_on_account_id"
    t.index ["code"], name: "index_disbursements_on_code"
    t.index ["created_at"], name: "index_disbursements_on_created_at"
    t.index ["status", "executed_at"], name: "index_disbursements_on_status_and_executed_at"
  end

  create_table "outlays", force: :cascade do |t|
    t.integer "amount"
    t.string "bsb"
    t.string "code"
    t.string "account_name"
    t.string "account_number"
    t.integer "disbursement_id"
    t.integer "status"
    t.integer "purpose"
    t.integer "payment_type"
    t.string "note"
    t.datetime "executed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["disbursement_id"], name: "index_outlays_on_disbursement_id"
  end

  create_table "transfers", force: :cascade do |t|
    t.string "code"
    t.string "identifier"
    t.string "posted_date"
    t.datetime "posted_datetime"
    t.string "connection_identifier"
    t.integer "account_id", null: false
    t.string "data_digest"
    t.string "psmain_code"
    t.string "reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_transfers_on_account_id"
  end

  add_foreign_key "disbursements", "accounts"
  add_foreign_key "outlays", "disbursements"
  add_foreign_key "transfers", "accounts"
end
