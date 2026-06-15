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

ActiveRecord::Schema[8.1].define(version: 2026_06_13_190933) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "calls", force: :cascade do |t|
    t.string "call_number"
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "ended_at"
    t.datetime "started_at", null: false
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_calls_on_campaign_id"
    t.index ["started_at"], name: "index_calls_on_started_at"
  end

  create_table "campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "source", null: false
    t.string "tracking_number", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_campaigns_on_lower_name", unique: true
    t.index ["tracking_number"], name: "index_campaigns_on_tracking_number", unique: true
  end

  add_foreign_key "calls", "campaigns"
end
