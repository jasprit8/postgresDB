-- =====================================================================
-- M2A Webhook Event Processor - mapping table DDL (PostgreSQL)
--
-- Purpose: the column -> field mapping the webhook apply reads to build the
--          Airtable upsert dynamically (monday_col_id -> airtable_field_id).
--
-- The webhook only READS from these tables. `mapping` has a FK to `task`
-- and the read joins them on task.board_id, so both tables (and the one
-- enum `mapping` needs) are included here to make the script self-contained
-- and runnable on an empty database.
--
-- Idempotent: safe to run more than once (IF NOT EXISTS / guarded enum).
-- =====================================================================

-- Needed for gen_random_uuid() (Postgres 13+ ships pgcrypto).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
-- mapping.cardinality
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mapping_cardinality') THEN
        CREATE TYPE mapping_cardinality AS ENUM ('one-to-one', 'one-to-many');
    END IF;
END$$;

-- task.status
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN
        CREATE TYPE task_status AS ENUM ('active', 'inactive', 'error');
    END IF;
END$$;

-- task.sync_mode
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sync_mode') THEN
        CREATE TYPE sync_mode AS ENUM ('full', 'increment');
    END IF;
END$$;

-- task.run_state
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'run_state') THEN
        CREATE TYPE run_state AS ENUM ('idle', 'processing', 'success', 'failure');
    END IF;
END$$;

-- ---------------------------------------------------------------------
-- task - one integration (Monday board -> Airtable table), 1 row per board.
-- The webhook read joins mapping -> task to resolve rules by board_id.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS task (
    task_id        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id       text        NOT NULL UNIQUE,          -- Monday board id; UNIQUE = 1:1 board<->task
    base_id        text        NOT NULL,                 -- Airtable base id
    table_id       text        NOT NULL,                 -- Airtable table id
    sync_mode      sync_mode   NOT NULL DEFAULT 'increment',
    schedule_cron  text,                                 -- e.g. */15 * * * * (scheduler dummy until enabled)
    status         task_status NOT NULL DEFAULT 'inactive',
    run_state      run_state   NOT NULL DEFAULT 'idle',  -- UI status only
    last_synced_at timestamptz,                          -- BATCH watermark (real-time watermark lives on webhook.last_event_at)
    owner_user_id  text        NOT NULL,                 -- from X-User-Id / Ping SSO
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

-- board_id is the webhook's lookup key.
CREATE UNIQUE INDEX IF NOT EXISTS uq_task_board ON task (board_id);

-- ---------------------------------------------------------------------
-- mapping - column -> field rules. Read by the webhook apply.
--   monday_col_id     : the Monday column id from the delta (e.g. 'status')
--   airtable_field_id : the target Airtable field name/id to write
-- The upsert/match key is the system-managed Monday Task ID (Airtable PK)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mapping (
    mapping_id        uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id           uuid                NOT NULL
                          REFERENCES task (task_id) ON DELETE CASCADE,
    monday_col_id     text                NOT NULL,
    airtable_field_id text                NOT NULL,
    is_subitem        boolean             NOT NULL DEFAULT false,   -- child (sub-item) field mapping
    cardinality       mapping_cardinality NOT NULL DEFAULT 'one-to-one'
);

-- Lookup index for the webhook read (all rules for a task/board).
CREATE INDEX IF NOT EXISTS ix_mapping_task ON mapping (task_id);

-- Prevent duplicate rules for the same column within a task.
CREATE UNIQUE INDEX IF NOT EXISTS uq_mapping_task_col
    ON mapping (task_id, monday_col_id, is_subitem);

-- =====================================================================
-- Read query used by the webhook apply (for the DB-service contract).
-- Given a Monday board_id, return the column -> field rules for it.
--
--   SELECT m.monday_col_id,
--          m.airtable_field_id,
--          m.is_subitem,
--          m.cardinality
--   FROM   mapping m
--   JOIN   task t ON t.task_id = m.task_id
--   WHERE  t.board_id = :boardId;
-- =====================================================================

-- ---------------------------------------------------------------------
-- OPTIONAL sample seed (uncomment to test the read end-to-end).
-- Maps Monday board 1234567890 -> Airtable base/table, with 3 column rules.
-- ---------------------------------------------------------------------
-- INSERT INTO task (board_id, base_id, table_id, owner_user_id, status)
-- VALUES ('1234567890', 'appXXXXXXXXXXXXXX', 'tblXXXXXXXXXXXXXX', 'seed@roche.com', 'active')
-- ON CONFLICT (board_id) DO NOTHING;
--
-- INSERT INTO mapping (task_id, monday_col_id, airtable_field_id)
-- SELECT t.task_id, v.col, v.field
-- FROM   task t
-- CROSS  JOIN (VALUES
--                ('name',   'Title'),
--                ('status', 'Deal Stage'),
--                ('date4',  'Due Date')
--            ) AS v(col, field)
-- WHERE  t.board_id = '1234567890'
-- ON CONFLICT (task_id, monday_col_id, is_subitem) DO NOTHING;