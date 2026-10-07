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

ActiveRecord::Schema[8.1].define(version: 2026_10_07_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "catalog_items", force: :cascade do |t|
    t.string "kind", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.text "description", null: false
    t.integer "points", default: 0, null: false
    t.string "visibility", null: false
    t.jsonb "params", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_catalog_items_on_key", unique: true
  end

  create_table "checks", force: :cascade do |t|
    t.bigint "race_id", null: false
    t.bigint "duo_id", null: false
    t.bigint "catalog_item_id", null: false
    t.string "kind", null: false
    t.boolean "achieved", default: false, null: false
    t.string "decision", default: "pending", null: false
    t.boolean "contested", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_item_id"], name: "index_checks_on_catalog_item_id"
    t.index ["duo_id"], name: "index_checks_on_duo_id"
    t.index ["race_id", "duo_id", "kind"], name: "index_checks_on_race_id_and_duo_id_and_kind", unique: true
    t.index ["race_id"], name: "index_checks_on_race_id"
  end

  create_table "cups", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.integer "position", null: false
    t.string "status", default: "setup", null: false
    t.bigint "game_master_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "position"], name: "index_cups_on_game_id_and_position", unique: true
    t.index ["game_id"], name: "index_cups_on_game_id"
    t.index ["game_master_id"], name: "index_cups_on_game_master_id"
  end

  create_table "disputes", force: :cascade do |t|
    t.bigint "check_id", null: false
    t.bigint "opened_by_id", null: false
    t.string "status", default: "open", null: false
    t.string "outcome"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_id"], name: "index_disputes_on_check_id"
    t.index ["opened_by_id"], name: "index_disputes_on_opened_by_id"
  end

  create_table "duos", force: :cascade do |t|
    t.bigint "cup_id", null: false
    t.bigint "pilot_id", null: false
    t.bigint "judge_id", null: false
    t.string "character"
    t.bigint "fil_rouge_item_id"
    t.bigint "special_action_item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cup_id"], name: "index_duos_on_cup_id"
    t.index ["fil_rouge_item_id"], name: "index_duos_on_fil_rouge_item_id"
    t.index ["judge_id"], name: "index_duos_on_judge_id"
    t.index ["pilot_id"], name: "index_duos_on_pilot_id"
    t.index ["special_action_item_id"], name: "index_duos_on_special_action_item_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "code", null: false
    t.string "status", default: "lobby", null: false
    t.bigint "host_id"
    t.boolean "rotate_game_master", default: true, null: false
    t.integer "cups_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_games_on_code", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.string "nickname", null: false
    t.string "session_token", null: false
    t.string "status", default: "connected", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "replaces_id"
    t.index "game_id, lower((nickname)::text)", name: "index_players_on_game_and_lower_nickname", unique: true
    t.index ["game_id"], name: "index_players_on_game_id"
    t.index ["replaces_id"], name: "index_players_on_replaces_id", unique: true
    t.index ["session_token"], name: "index_players_on_session_token", unique: true
  end

  create_table "race_results", force: :cascade do |t|
    t.bigint "race_id", null: false
    t.bigint "duo_id", null: false
    t.integer "position", null: false
    t.boolean "position_points_cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pilot_id"
    t.index ["duo_id"], name: "index_race_results_on_duo_id"
    t.index ["pilot_id"], name: "index_race_results_on_pilot_id"
    t.index ["race_id", "duo_id"], name: "index_race_results_on_race_id_and_duo_id", unique: true
    t.index ["race_id"], name: "index_race_results_on_race_id"
  end

  create_table "races", force: :cascade do |t|
    t.bigint "cup_id", null: false
    t.integer "position", null: false
    t.string "status", default: "pending", null: false
    t.bigint "complication_item_id"
    t.jsonb "target_duo_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["complication_item_id"], name: "index_races_on_complication_item_id"
    t.index ["cup_id", "position"], name: "index_races_on_cup_id_and_position", unique: true
    t.index ["cup_id"], name: "index_races_on_cup_id"
  end

  create_table "score_entries", force: :cascade do |t|
    t.bigint "game_id", null: false
    t.bigint "cup_id", null: false
    t.bigint "race_id", null: false
    t.bigint "player_id", null: false
    t.bigint "check_id"
    t.string "kind", null: false
    t.integer "points", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_id"], name: "index_score_entries_on_check_id"
    t.index ["cup_id"], name: "index_score_entries_on_cup_id"
    t.index ["game_id"], name: "index_score_entries_on_game_id"
    t.index ["player_id"], name: "index_score_entries_on_player_id"
    t.index ["race_id"], name: "index_score_entries_on_race_id"
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "dispute_id", null: false
    t.bigint "player_id", null: false
    t.boolean "approve", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispute_id", "player_id"], name: "index_votes_on_dispute_id_and_player_id", unique: true
    t.index ["dispute_id"], name: "index_votes_on_dispute_id"
    t.index ["player_id"], name: "index_votes_on_player_id"
  end

  add_foreign_key "checks", "catalog_items"
  add_foreign_key "checks", "duos"
  add_foreign_key "checks", "races"
  add_foreign_key "cups", "games"
  add_foreign_key "cups", "players", column: "game_master_id"
  add_foreign_key "disputes", "checks"
  add_foreign_key "disputes", "players", column: "opened_by_id"
  add_foreign_key "duos", "catalog_items", column: "fil_rouge_item_id"
  add_foreign_key "duos", "catalog_items", column: "special_action_item_id"
  add_foreign_key "duos", "cups"
  add_foreign_key "duos", "players", column: "judge_id"
  add_foreign_key "duos", "players", column: "pilot_id"
  add_foreign_key "games", "players", column: "host_id", on_delete: :nullify
  add_foreign_key "players", "games"
  add_foreign_key "players", "players", column: "replaces_id"
  add_foreign_key "race_results", "duos"
  add_foreign_key "race_results", "players", column: "pilot_id"
  add_foreign_key "race_results", "races"
  add_foreign_key "races", "catalog_items", column: "complication_item_id"
  add_foreign_key "races", "cups"
  add_foreign_key "score_entries", "checks"
  add_foreign_key "score_entries", "cups"
  add_foreign_key "score_entries", "games"
  add_foreign_key "score_entries", "players"
  add_foreign_key "score_entries", "races"
  add_foreign_key "votes", "disputes"
  add_foreign_key "votes", "players"
end
