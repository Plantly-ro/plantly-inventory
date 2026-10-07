-- user_version 12
CREATE TABLE "species" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "scientific_name" TEXT NOT NULL, "common_names_json" TEXT NOT NULL, "default_care_json" TEXT NULL, "is_seed" INTEGER NOT NULL DEFAULT 0 CHECK ("is_seed" IN (0, 1)), "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "locations" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "parent_id" TEXT NULL, "name" TEXT NOT NULL, "kind" TEXT NOT NULL, "light" TEXT NULL, "humidity_min" INTEGER NULL, "humidity_max" INTEGER NULL, "temp_min_c" REAL NULL, "temp_max_c" REAL NULL, "is_outdoor" INTEGER NOT NULL DEFAULT 0 CHECK ("is_outdoor" IN (0, 1)), "lat" REAL NULL, "lon" REAL NULL, "notes" TEXT NULL, "map_photo_sha" TEXT NULL, "notifications_muted" INTEGER NOT NULL DEFAULT 0 CHECK ("notifications_muted" IN (0, 1)), "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "plants" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "nickname" TEXT NOT NULL, "species_id" TEXT NULL, "location_id" TEXT NULL, "pin_x" REAL NULL, "pin_y" REAL NULL, "notifications_muted" INTEGER NOT NULL DEFAULT 0 CHECK ("notifications_muted" IN (0, 1)), "status" TEXT NOT NULL, "acquired_at" INTEGER NULL, "source" TEXT NULL, "notes" TEXT NULL, "pot_size_cm" INTEGER NULL, "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "photos" ("sha256" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "width" INTEGER NULL, "height" INTEGER NULL, "mime" TEXT NOT NULL, "bytes" INTEGER NOT NULL, "taken_at" INTEGER NULL, "exif_json" TEXT NULL, "local_path" TEXT NULL, "remote_state" TEXT NOT NULL DEFAULT 'local', "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("sha256"));
CREATE TABLE "plant_photos" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "plant_id" TEXT NOT NULL, "photo_sha" TEXT NOT NULL, "caption" TEXT NULL, "captured_at" INTEGER NULL, "display_order" INTEGER NOT NULL DEFAULT 0, "added_hlc" TEXT NOT NULL, "removed_hlc" TEXT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "location_photos" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "location_id" TEXT NOT NULL, "photo_sha" TEXT NOT NULL, "caption" TEXT NULL, "captured_at" INTEGER NULL, "display_order" INTEGER NOT NULL DEFAULT 0, "added_hlc" TEXT NOT NULL, "removed_hlc" TEXT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "tags" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "name" TEXT NOT NULL, "color" TEXT NULL, "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "plant_tags" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "plant_id" TEXT NOT NULL, "tag_id" TEXT NOT NULL, "added_hlc" TEXT NOT NULL, "removed_hlc" TEXT NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "care_events" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "plant_id" TEXT NOT NULL, "type" TEXT NOT NULL, "done_at" INTEGER NOT NULL, "notes" TEXT NULL, "dose" TEXT NULL, "product" TEXT NULL, "photo_sha" TEXT NULL, "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "actor_user_id" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "care_schedules" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "plant_id" TEXT NOT NULL, "type" TEXT NOT NULL, "base_interval_days" REAL NOT NULL, "current_interval_days" REAL NOT NULL, "last_done_at" INTEGER NULL, "next_due_at" INTEGER NULL, "snooze_count" INTEGER NOT NULL DEFAULT 0, "recent_events_json" TEXT NOT NULL DEFAULT '[]', "enabled" INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)), "recurrence_mode" TEXT NOT NULL DEFAULT 'after_completion', "notifications_muted" INTEGER NOT NULL DEFAULT 0 CHECK ("notifications_muted" IN (0, 1)), "assignee_user_id" TEXT NULL, "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"), UNIQUE(tenant_id, plant_id, type));
CREATE TABLE "inventory_transactions" ("id" TEXT NOT NULL, "tenant_id" TEXT NOT NULL, "type" TEXT NOT NULL, "parent_plant_id" TEXT NULL, "child_plant_id" TEXT NULL, "plant_id" TEXT NULL, "counterparty" TEXT NULL, "at" INTEGER NOT NULL, "notes" TEXT NULL, "amount_minor" INTEGER NULL, "currency" TEXT NULL, "updated_hlc" TEXT NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "sync_ops" ("seq" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "tenant_id" TEXT NOT NULL, "entity" TEXT NOT NULL, "entity_id" TEXT NOT NULL, "field" TEXT NOT NULL, "value_json" TEXT NULL, "hlc" TEXT NOT NULL, "device_id" TEXT NOT NULL, "pushed_at" INTEGER NULL, "user_id" TEXT NULL);
CREATE TABLE "sync_rejections" ("op_seq" INTEGER NOT NULL, "tenant_id" TEXT NOT NULL, "entity" TEXT NOT NULL, "entity_id" TEXT NOT NULL, "field" TEXT NOT NULL, "reason" TEXT NOT NULL, "hlc" TEXT NOT NULL, "at" INTEGER NOT NULL, "parked" INTEGER NOT NULL DEFAULT 0 CHECK ("parked" IN (0, 1)), PRIMARY KEY ("op_seq"));
CREATE INDEX idx_plants_tenant ON plants(tenant_id);
CREATE INDEX idx_plants_location ON plants(tenant_id, location_id);
CREATE INDEX idx_plants_status ON plants(tenant_id, status);
CREATE INDEX idx_care_events_plant_done ON care_events(tenant_id, plant_id, done_at DESC);
CREATE INDEX idx_schedules_due ON care_schedules(tenant_id, enabled, next_due_at);
CREATE INDEX idx_sync_ops_tenant_pending ON sync_ops(tenant_id, pushed_at) WHERE pushed_at IS NULL;
CREATE INDEX idx_sync_ops_key ON sync_ops(tenant_id, entity, entity_id, field);
CREATE UNIQUE INDEX idx_tags_tenant_name ON tags(tenant_id, name);
CREATE INDEX idx_sync_rejections_tenant ON sync_rejections(tenant_id);
CREATE UNIQUE INDEX idx_plant_photos_unique_add ON plant_photos(tenant_id, plant_id, photo_sha, added_hlc);
CREATE VIRTUAL TABLE plants_fts USING fts5(
        plant_id UNINDEXED,
        tenant_id UNINDEXED,
        nickname,
        notes,
        tokenize = 'unicode61 remove_diacritics 2'
      );
