// main.ts — the composition root (I/O + real time live here, never in the sim).
// Boot chain ported from SideQuestAppV2 server/main.ts:
//
//   config → systemClock → openDb(+migrate) → repo.load ?? createWorld
//     → createLoop → createHttpServer(Hono) → attachGateway(/ws) → listen(PORT)
//     → autosave interval → SIGTERM/SIGINT: stop, final save, close

import { loadConfig } from './config.js';
import { openDb } from './persistence/db.js';
import { load, save } from './persistence/repo.js';
import type { World } from './shared/entities.js';
import { createLoop, type Clock } from './sim/loop.js';
import { createWorld } from './sim/world.js';
import { createApp, createHttpServer } from './app.js';
import { attachGateway, type Gateway } from './net/gateway.js';
// Handler registration side-effects: the combat + economy modules plug their ops
// into the sim/commands registry at module load.
import './sim/commands_combat.js';
import './sim/commands_economy.js';

/**
 * Milestone fingerprint — the durable-progress beats that force an immediate save
 * (DESIGN §Persistence): a front completing, a tower being built/upgraded/
 * salvaged/felled, a minion changing state (dispatched/returned/injured). Cheap
 * scalar hash recomputed per tick; a change flushes between ticks so a crash right
 * after the beat can never undo it. Durability wear deliberately excluded — the
 * 15 s autosave covers gradual drift.
 */
function milestoneFingerprint(world: World): string {
  let completedFronts = 0;
  for (const f of world.fronts.values()) if (f.completedAt !== undefined) completedFronts += 1;
  const towers: string[] = [];
  for (const t of world.towers.values()) towers.push(`${t.id}:${t.level}:${t.isRubble ? 1 : 0}`);
  towers.sort();
  const minions: string[] = [];
  for (const roster of world.minions.values()) {
    for (const m of roster) minions.push(`${m.id}:${m.state}:${m.job !== null ? 1 : 0}`);
  }
  minions.sort();
  return `${completedFronts}|${towers.join(';')}|${minions.join(';')}`;
}

function main(): void {
  const config = loadConfig();

  // The real-time clock — the ONLY place Date.now enters the system.
  const systemClock: Clock = { now: () => Date.now() };

  const db = openDb(config.DB_PATH);
  const world =
    load(db) ??
    createWorld(config.WORLD_SEED, config.ORIGIN, systemClock.now(), {
      dailyResetUtcH: config.DAILY_RESET_UTC_H,
    });

  const saveNow = (label: string): void => {
    try {
      save(db, world);
    } catch (err) {
      console.error(`[yas] ${label} save failed:`, err);
    }
  };

  // Gateway is created after the loop, but the loop's onTick must reach it — closure bridge.
  let gateway: Gateway | undefined;
  let lastMilestoneFp = milestoneFingerprint(world);
  const loop = createLoop({
    world,
    tickHz: config.TICK_HZ,
    clock: systemClock,
    onTick: (w, tick, now) => {
      gateway?.onTick(w, tick, now);
      const fp = milestoneFingerprint(w);
      if (fp !== lastMilestoneFp) {
        lastMilestoneFp = fp;
        saveNow('milestone');
      }
    },
  });
  loop.start();

  const app = createApp({ world, clock: systemClock, startedAt: systemClock.now() });
  const http = createHttpServer(app);
  gateway = attachGateway(http, world, { clock: systemClock, tickHz: config.TICK_HZ });

  http.listen(config.PORT, () => {
    console.log(
      `[yas] listening on :${config.PORT}  ws=/ws  seed=${config.WORLD_SEED}  ` +
        `origin=${config.ORIGIN.lat},${config.ORIGIN.lng}  tickHz=${config.TICK_HZ}  db=${config.DB_PATH}`,
    );
  });

  const autosave = setInterval(() => saveNow('autosave'), config.AUTOSAVE_MS);

  let shuttingDown = false;
  const shutdown = (signal: string): void => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`[yas] ${signal} — saving and shutting down`);
    clearInterval(autosave);
    loop.stop();
    gateway?.close();
    saveNow('final');
    http.close();
    db.close();
    process.exit(0);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main();
