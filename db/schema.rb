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

ActiveRecord::Schema[8.0].define(version: 2025_10_30_141618) do
  create_table "group_permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "permission", null: false
    t.datetime "created_at"
    t.integer "created_by"
  end

  create_table "group_tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
  end

  create_table "group_updates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.datetime "created_at", null: false
  end

  create_table "groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "group_type", default: 1, null: false
    t.bigint "department_id"
    t.string "group_name", limit: 100, null: false
    t.string "group_description", limit: 500
    t.boolean "is_public", null: false
    t.string "color_default", limit: 10, null: false
    t.string "color_highlight", limit: 10, null: false
    t.boolean "is_published", null: false
    t.datetime "deleted_at"
    t.integer "created_by"
    t.integer "updated_by"
    t.integer "deleted_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "group_permission_id"
    t.string "group_code"
  end

  create_table "schedule_files", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "schedule_link_id", null: false
    t.integer "created_by", null: false
    t.string "file_path", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["schedule_link_id"], name: "index_schedule_files_on_schedule_link_id"
  end

  create_table "schedule_links", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title", limit: 100, null: false
    t.integer "place_id"
    t.string "place_text", limit: 20
    t.text "description"
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.boolean "is_allday", default: false, null: false
    t.integer "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "schedules", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "schedule_link_id", null: false
    t.string "memo"
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.integer "created_by", null: false
    t.integer "updated_by"
    t.integer "deleted_by"
    t.string "schedule_code"
    t.index ["schedule_link_id"], name: "index_schedules_on_schedule_link_id"
  end

  create_table "tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
  end

  create_table "user_groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "group_id"
    t.datetime "created_at", precision: nil
    t.bigint "user_id"
    t.datetime "updated_at"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "default_group_id", null: false
    t.string "user_number", limit: 20, null: false
    t.string "name", limit: 20, null: false
    t.string "email", limit: 50, null: false
    t.string "department", limit: 30, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
