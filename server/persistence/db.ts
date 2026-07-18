// persistence/db.ts — open the SQLite durability layer and apply schema.sql
// idempotently. Synchronous (better-sqlite3) — runs between ticks, never mid-tick.
// This is the I/O edge: NOT the sim, so fs/db access is allowed here.
// Ported from SideQuestAppV2 server/persistence/db.ts.

import Database from 'better-sqlite3';
import { mkdirSync, readFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export type Db = Database.Database;

const SCHEMA_PATH = fileURLToPath(new URL('./schema.sql', import.meta.url));

/**
 * openDb(dbPath) — open (creating parent dirs) and migrate the database. Applying
 * schema.sql is idempotent (CREATE TABLE IF NOT EXISTS), so this is safe on every
 * boot. `:memory:` is honored for tests.
 */
export function openDb(dbPath: string): Db {
  if (dbPath !== ':memory:') mkdirSync(dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.exec(readFileSync(SCHEMA_PATH, 'utf8'));
  migrate(db);
  return db;
}

/**
 * migrate(db) — additive, idempotent column migrations. schema.sql builds a fresh
 * DB fully but cannot add columns to a table an earlier schema already created;
 * ADD COLUMN entries land here (never drop) when the persisted shape changes, in
 * step with a SCHEMA_VERSION bump in sim/world.ts. Empty until the first bump.
 */
function migrate(db: Db): void {
  void db;
}
