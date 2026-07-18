// config.ts — the ONLY env reader in the package (DESIGN §Ops). I/O edge: it may
// read process.env, nothing else. Ported from SideQuestAppV2 server/config.ts
// (DAILY_RESET_UTC_H added for the §10 daily rollover).

import { TICK_HZ as DEFAULT_TICK_HZ } from './shared/constants.js';
import { DEFAULT_DAILY_RESET_UTC_H } from './sim/world.js';

export interface Config {
  PORT: number;
  DATA_DIR: string;
  /** Full path to the SQLite file (DATA_DIR/world.db unless DB_PATH overrides). */
  DB_PATH: string;
  WORLD_SEED: string;
  ORIGIN: { lat: number; lng: number };
  TICK_HZ: number;
  AUTOSAVE_MS: number;
  /** §10 daily-quest reset hour (UTC) — "dawn local" approximation. */
  DAILY_RESET_UTC_H: number;
}

function num(v: string | undefined, dflt: number): number {
  if (v === undefined || v === '') return dflt;
  const n = Number(v);
  return Number.isFinite(n) ? n : dflt;
}

function str(v: string | undefined, dflt: string): string {
  return v === undefined || v === '' ? dflt : v;
}

/**
 * loadConfig — build a Config from an env bag (defaults to process.env).
 * Pure aside from reading the passed-in env; no filesystem or network access.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const DATA_DIR = str(env.DATA_DIR, './data');
  return {
    PORT: num(env.PORT, 8080),
    DATA_DIR,
    DB_PATH: str(env.DB_PATH, `${DATA_DIR.replace(/\/+$/, '')}/world.db`),
    WORLD_SEED: str(env.WORLD_SEED, 'yas-v1'),
    ORIGIN: {
      lat: num(env.ORIGIN_LAT, 37.7749),
      lng: num(env.ORIGIN_LNG, -122.4194),
    },
    TICK_HZ: num(env.TICK_HZ, DEFAULT_TICK_HZ),
    AUTOSAVE_MS: num(env.AUTOSAVE_MS, 15_000),
    DAILY_RESET_UTC_H: num(env.DAILY_RESET_UTC_H, DEFAULT_DAILY_RESET_UTC_H),
  };
}
