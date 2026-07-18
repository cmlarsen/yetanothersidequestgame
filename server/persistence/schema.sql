-- persistence/schema.sql — the durability layer (DESIGN §Persistence). Idempotent
-- DDL (CREATE IF NOT EXISTS) applied on every boot by db.ts. The in-memory World is
-- authoritative; these tables are a crash-consistent snapshot of sim/world.ts
-- serialize(): scalar columns for the queried fields + a `data` JSON blob for the
-- full persisted entity. Runtime state (mobs, combat, interest, run/death machines)
-- is never rowed — it re-derives from seed + persisted progress.
-- Ported from SideQuestAppV2 server/persistence/schema.sql, re-tabled onto the YAS
-- entity set.

PRAGMA journal_mode = WAL;

-- world singleton (one row, id = 1). `data` carries the small world-level
-- collections without tables of their own: {fronts, goldDrops} exactly as
-- serialize() projects them (front progress only — geometry re-derives from seed).
CREATE TABLE IF NOT EXISTS world_meta (
  id             INTEGER PRIMARY KEY CHECK (id = 1),
  seed           TEXT    NOT NULL,
  origin_lat     REAL    NOT NULL,
  origin_lng     REAL    NOT NULL,
  created_at     INTEGER NOT NULL,
  tick           INTEGER NOT NULL DEFAULT 0,   -- persists so the RNG cursor can't save-scum
  schema_version INTEGER NOT NULL DEFAULT 1,
  daily_reset_at INTEGER NOT NULL DEFAULT 0,
  data           TEXT    NOT NULL              -- JSON {fronts, goldDrops}
);

-- §2 player. Inventory/equipment/quests/settings live inside the `data` blob;
-- the scalar columns exist for queries (JOIN-by-name, RESUME-by-token, ops peeks).
CREATE TABLE IF NOT EXISTS player (
  id            TEXT    PRIMARY KEY,
  name          TEXT    NOT NULL,              -- gamertag (untrusted name-only identity)
  session_token TEXT,
  level         INTEGER NOT NULL DEFAULT 1,
  gold          INTEGER NOT NULL DEFAULT 0,
  pos_x         REAL    NOT NULL DEFAULT 0,
  pos_y         REAL    NOT NULL DEFAULT 0,
  updated_at    INTEGER NOT NULL DEFAULT 0,
  data          TEXT    NOT NULL               -- full persisted Player as JSON
);
CREATE INDEX IF NOT EXISTS idx_player_name  ON player(name);
CREATE INDEX IF NOT EXISTS idx_player_token ON player(session_token);

-- §1 hex ownership — ONLY non-neutral hexes get rows (absent = neutral, exactly
-- like World.hexes). HexState is fully covered by these columns, so no blob;
-- contestedMobId is runtime (references a re-derived mob) and never persists.
CREATE TABLE IF NOT EXISTS hex (
  key        TEXT    PRIMARY KEY,              -- "q,r"
  owner      TEXT    NOT NULL,                 -- 'players' | 'gloom'
  front_id   TEXT    NOT NULL,
  tower_id   TEXT,
  changed_at INTEGER NOT NULL
);

-- §8 tower.
CREATE TABLE IF NOT EXISTS tower (
  id       TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  hex_key  TEXT NOT NULL,
  data     TEXT NOT NULL                       -- full persisted Tower as JSON
);
CREATE INDEX IF NOT EXISTS idx_tower_owner ON tower(owner_id);

-- §9 minion. `slot` is the roster position — load re-assembles each owner's roster
-- in this order so a save/load round-trip re-serializes byte-identically.
CREATE TABLE IF NOT EXISTS minion (
  id       TEXT    PRIMARY KEY,
  owner_id TEXT    NOT NULL,
  slot     INTEGER NOT NULL,
  data     TEXT    NOT NULL                    -- full persisted Minion as JSON
);
CREATE INDEX IF NOT EXISTS idx_minion_owner ON minion(owner_id);

-- §6 chest state — OPENED/LOOTED ONLY (the V2 poi_state pattern): an unopened
-- chest is treated as re-derivable by the chest system and carries no row; only
-- the opened fact must survive a restart (so a chest can never be re-looted while
-- its record lives).
CREATE TABLE IF NOT EXISTS chest_state (
  chest_id  TEXT PRIMARY KEY,
  opened_by TEXT NOT NULL,
  data      TEXT NOT NULL                      -- full persisted Chest as JSON
);

-- §12 party.
CREATE TABLE IF NOT EXISTS party (
  id   TEXT PRIMARY KEY,
  data TEXT NOT NULL                           -- full persisted Party as JSON
);

-- §10 quest progress — the queryable projection of Player.quests, one row per
-- (player, quest). Written and read in lockstep with the player blob.
CREATE TABLE IF NOT EXISTS quest_state (
  player_id TEXT    NOT NULL,
  quest_id  TEXT    NOT NULL,
  progress  REAL    NOT NULL DEFAULT 0,
  state     TEXT    NOT NULL,                  -- 'active' | 'claimable' | 'done'
  reset_at  INTEGER,                           -- dailies only
  PRIMARY KEY (player_id, quest_id)
);
