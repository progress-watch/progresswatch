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

ActiveRecord::Schema[8.1].define(version: 2026_08_02_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "spaces", primary_key: "uuid", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
  end

  create_table "tasks", primary_key: "uuid", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration"
    t.datetime "finished_at"
    t.string "parent_uuid", limit: 36
    t.string "source"
    t.string "space_uuid", limit: 36, null: false
    t.string "title"
    t.index ["parent_uuid"], name: "index_tasks_on_parent_uuid"
    t.index ["space_uuid"], name: "index_tasks_on_space_uuid"
  end

  add_foreign_key "tasks", "spaces", column: "space_uuid", primary_key: "uuid"
  add_foreign_key "tasks", "tasks", column: "parent_uuid", primary_key: "uuid"
end
