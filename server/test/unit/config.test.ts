// config.ts is the package's only env reader — pin its defaults and parsing so a
// typo'd fly.toml or missing secret degrades to a sane boot, never a crash.

import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config.js';

describe('loadConfig defaults', () => {
  it('yields the documented defaults from an empty env', () => {
    const c = loadConfig({});
    expect(c.PORT).toBe(8080);
    expect(c.DATA_DIR).toBe('./data');
    expect(c.DB_PATH).toBe('./data/world.db');
    expect(c.WORLD_SEED).toBe('yas-v1');
    expect(c.ORIGIN).toEqual({ lat: 37.7749, lng: -122.4194 });
    expect(c.TICK_HZ).toBe(10);
    expect(c.AUTOSAVE_MS).toBe(15_000);
    expect(c.DAILY_RESET_UTC_H).toBe(13);
  });

  it('treats empty-string values as unset', () => {
    const c = loadConfig({ PORT: '', WORLD_SEED: '', ORIGIN_LAT: '' });
    expect(c.PORT).toBe(8080);
    expect(c.WORLD_SEED).toBe('yas-v1');
    expect(c.ORIGIN.lat).toBe(37.7749);
  });
});

describe('loadConfig overrides', () => {
  it('reads every env override', () => {
    const c = loadConfig({
      PORT: '9090',
      DATA_DIR: '/somewhere',
      WORLD_SEED: 'test-seed',
      ORIGIN_LAT: '40.2338',
      ORIGIN_LNG: '-111.6585',
      TICK_HZ: '20',
      AUTOSAVE_MS: '5000',
      DAILY_RESET_UTC_H: '6',
    });
    expect(c.PORT).toBe(9090);
    expect(c.DATA_DIR).toBe('/somewhere');
    expect(c.WORLD_SEED).toBe('test-seed');
    expect(c.ORIGIN).toEqual({ lat: 40.2338, lng: -111.6585 });
    expect(c.TICK_HZ).toBe(20);
    expect(c.AUTOSAVE_MS).toBe(5000);
    expect(c.DAILY_RESET_UTC_H).toBe(6);
  });

  it('derives DB_PATH from DATA_DIR (trailing slashes stripped)', () => {
    expect(loadConfig({ DATA_DIR: '/data' }).DB_PATH).toBe('/data/world.db');
    expect(loadConfig({ DATA_DIR: '/data//' }).DB_PATH).toBe('/data/world.db');
  });

  it('an explicit DB_PATH wins over the DATA_DIR derivation', () => {
    const c = loadConfig({ DATA_DIR: '/data', DB_PATH: '/elsewhere/w.db' });
    expect(c.DB_PATH).toBe('/elsewhere/w.db');
  });

  it('falls back to defaults on non-numeric numbers', () => {
    const c = loadConfig({ PORT: 'not-a-port', TICK_HZ: 'NaN', AUTOSAVE_MS: 'soon' });
    expect(c.PORT).toBe(8080);
    expect(c.TICK_HZ).toBe(10);
    expect(c.AUTOSAVE_MS).toBe(15_000);
  });
});
