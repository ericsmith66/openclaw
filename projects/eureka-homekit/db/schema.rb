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

ActiveRecord::Schema[8.1].define(version: 2026_02_17_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accessories", force: :cascade do |t|
    t.jsonb "characteristics", default: {}
    t.datetime "created_at", null: false
    t.datetime "last_seen_at"
    t.string "name"
    t.jsonb "raw_data", default: {}, null: false
    t.bigint "room_id", null: false
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index [ "last_seen_at" ], name: "index_accessories_on_last_seen_at"
    t.index [ "name" ], name: "index_accessories_on_name"
    t.index [ "room_id" ], name: "index_accessories_on_room_id"
    t.index [ "uuid" ], name: "index_accessories_on_uuid", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index [ "blob_id" ], name: "index_active_storage_attachments_on_blob_id"
    t.index [ "record_type", "record_id", "name", "blob_id" ], name: "index_active_storage_attachments_uniqueness", unique: true
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
    t.index [ "key" ], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index [ "blob_id", "variation_digest" ], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "control_events", force: :cascade do |t|
    t.bigint "accessory_id"
    t.string "action_type", null: false
    t.string "characteristic_name"
    t.datetime "created_at", null: false
    t.string "error_message"
    t.float "latency_ms"
    t.string "new_value"
    t.string "old_value"
    t.string "request_id"
    t.bigint "scene_id"
    t.string "source"
    t.boolean "success", default: true, null: false
    t.datetime "updated_at", null: false
    t.string "user_ip"
    t.index [ "accessory_id" ], name: "index_control_events_on_accessory_id"
    t.index [ "action_type" ], name: "index_control_events_on_action_type"
    t.index [ "created_at" ], name: "index_control_events_on_created_at"
    t.index [ "scene_id" ], name: "index_control_events_on_scene_id"
    t.index [ "success" ], name: "index_control_events_on_success"
  end

  create_table "floorplans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "home_id", null: false
    t.integer "level"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index [ "home_id" ], name: "index_floorplans_on_home_id"
  end

  create_table "homekit_events", force: :cascade do |t|
    t.bigint "accessory_id"
    t.string "accessory_name"
    t.string "characteristic"
    t.datetime "created_at", null: false
    t.string "event_type"
    t.jsonb "raw_payload"
    t.bigint "sensor_id"
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index [ "accessory_id" ], name: "index_homekit_events_on_accessory_id"
    t.index [ "accessory_name" ], name: "index_homekit_events_on_accessory_name"
    t.index [ "event_type" ], name: "index_homekit_events_on_event_type"
    t.index [ "sensor_id", "timestamp" ], name: "index_homekit_events_deduplication"
    t.index [ "sensor_id" ], name: "index_homekit_events_on_sensor_id"
    t.index [ "timestamp" ], name: "index_homekit_events_on_timestamp"
  end

  create_table "homes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "homekit_home_id"
    t.string "name"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index [ "name" ], name: "index_homes_on_name"
    t.index [ "uuid" ], name: "index_homes_on_uuid", unique: true
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "home_id", null: false
    t.datetime "last_event_at"
    t.datetime "last_motion_at"
    t.string "name"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index [ "home_id" ], name: "index_rooms_on_home_id"
    t.index [ "last_event_at" ], name: "index_rooms_on_last_event_at"
    t.index [ "last_motion_at" ], name: "index_rooms_on_last_motion_at"
    t.index [ "name" ], name: "index_rooms_on_name"
    t.index [ "uuid" ], name: "index_rooms_on_uuid", unique: true
  end

  create_table "scene_accessories", force: :cascade do |t|
    t.bigint "accessory_id", null: false
    t.datetime "created_at", null: false
    t.bigint "scene_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "accessory_id" ], name: "index_scene_accessories_on_accessory_id"
    t.index [ "scene_id" ], name: "index_scene_accessories_on_scene_id"
  end

  create_table "scenes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "home_id", null: false
    t.jsonb "metadata", default: {}
    t.string "name"
    t.jsonb "raw_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index [ "home_id" ], name: "index_scenes_on_home_id"
    t.index [ "name" ], name: "index_scenes_on_name"
    t.index [ "uuid" ], name: "index_scenes_on_uuid", unique: true
  end

  create_table "sensor_value_definitions", force: :cascade do |t|
    t.bigint "accessory_id"
    t.datetime "created_at", null: false
    t.string "label"
    t.datetime "last_seen_at"
    t.integer "occurrence_count", default: 0
    t.bigint "room_id"
    t.bigint "sensor_id"
    t.string "units"
    t.datetime "updated_at", null: false
    t.string "value"
    t.index [ "accessory_id" ], name: "index_sensor_value_definitions_on_accessory_id"
    t.index [ "room_id" ], name: "index_sensor_value_definitions_on_room_id"
    t.index [ "sensor_id", "value" ], name: "index_sensor_value_definitions_on_sensor_id_and_value", unique: true
    t.index [ "sensor_id" ], name: "index_sensor_value_definitions_on_sensor_id"
  end

  create_table "sensors", force: :cascade do |t|
    t.bigint "accessory_id", null: false
    t.string "characteristic_homekit_type"
    t.string "characteristic_type", null: false
    t.string "characteristic_uuid", null: false
    t.datetime "created_at", null: false
    t.jsonb "current_value"
    t.boolean "is_writable", default: false
    t.datetime "last_event_stored_at"
    t.datetime "last_seen_at"
    t.datetime "last_updated_at"
    t.float "max_value"
    t.jsonb "metadata", default: {}
    t.float "min_value"
    t.jsonb "properties", default: []
    t.string "service_type", null: false
    t.string "service_uuid", null: false
    t.float "step_value"
    t.boolean "supports_events", default: false
    t.string "units"
    t.datetime "updated_at", null: false
    t.string "value_format"
    t.index [ "accessory_id", "characteristic_uuid" ], name: "index_sensors_on_accessory_and_characteristic", unique: true
    t.index [ "accessory_id" ], name: "index_sensors_on_accessory_id"
    t.index [ "characteristic_type" ], name: "index_sensors_on_characteristic_type"
    t.index [ "last_event_stored_at" ], name: "index_sensors_on_last_event_stored_at"
    t.index [ "last_seen_at" ], name: "index_sensors_on_last_seen_at"
    t.index [ "last_updated_at" ], name: "index_sensors_on_last_updated_at"
    t.index [ "service_type" ], name: "index_sensors_on_service_type"
    t.index [ "supports_events" ], name: "index_sensors_on_supports_events"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "favorites", default: []
    t.jsonb "favorites_order", default: []
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "session_id" ], name: "index_user_preferences_on_session_id", unique: true
  end

  add_foreign_key "accessories", "rooms"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "control_events", "accessories"
  add_foreign_key "control_events", "scenes"
  add_foreign_key "floorplans", "homes"
  add_foreign_key "homekit_events", "accessories"
  add_foreign_key "homekit_events", "sensors"
  add_foreign_key "rooms", "homes"
  add_foreign_key "scene_accessories", "accessories"
  add_foreign_key "scene_accessories", "scenes"
  add_foreign_key "scenes", "homes"
  add_foreign_key "sensor_value_definitions", "accessories"
  add_foreign_key "sensor_value_definitions", "rooms"
  add_foreign_key "sensor_value_definitions", "sensors"
  add_foreign_key "sensors", "accessories"
end
