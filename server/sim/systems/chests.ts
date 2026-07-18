// sim/systems/chests.ts — §6 chest spawns + the CHEST_OPEN resolution. PURE,
// CLOCK-INJECTED, deterministic: spawn cadence compares injected `now` against
// per-player stamps, placement draws from seededRng(seed, 'chest-spawn', player,
// tick), and the 3-item staged roll rides the per-command rng. Chests persist
// (world.chests, P); the cadence stamps and opened-cull timers are runtime-only.

import type { Chest, Player, World } from '../../shared/entities.js';
import type { ServerMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import type { Rng } from '../../shared/rng.js';
import { seededRng } from '../../shared/rng.js';
import { itemDef } from '../../shared/catalog.js';
import { CHEST_NOTIFY_RADIUS_M, CHEST_OPEN_RADIUS_M } from '../../shared/tuning.js';
import { hexCenter, hexKeysWithin, parseHexKey } from '../../shared/hexgrid.js';
import { distM, within } from '../../shared/geo.js';
import { buildInventoryUpdate, registerTicker } from '../world.js';
import { err } from '../commands.js';
import { grantGold, grantXp, registerChestSpawner } from './territory.js';
import { pushGameEvents } from './outbox.js';
import { rollChestLoot } from './loot.js';

// Cadence/placement tuning — not GAME-RULES DEFAULTs (§6 fixes the gates and the
// item count, not the spawn rate); local until design promotes them.
export const CHEST_SPAWN_INTERVAL_MS = 180_000;
export const CHEST_SPAWN_RADIUS_M = 150;
export const CHEST_SPAWN_MIN_M = 25;
/** Stop spawning near a player once this many unopened chests sit within 200 m. */
export const CHEST_MAX_NEARBY = 2;
/** Opened chests linger briefly (idempotent re-sends) then cull — entities.ts note. */
export const CHEST_CULL_MS = 60_000;
export const CHEST_GOLD_MIN = 20;
export const CHEST_GOLD_MAX = 60;
export const CHEST_XP = 25;

// Runtime-only stamps, WeakMap-keyed by World identity.
const nextSpawnAt = new WeakMap<World, Map<string, number>>();
const openedAt = new WeakMap<World, Map<string, number>>();

function stamps(world: World): Map<string, number> {
  let m = nextSpawnAt.get(world);
  if (!m) {
    m = new Map();
    nextSpawnAt.set(world, m);
  }
  return m;
}

function openedStamps(world: World): Map<string, number> {
  let m = openedAt.get(world);
  if (!m) {
    m = new Map();
    openedAt.set(world, m);
  }
  return m;
}

function spawnChest(world: World, id: string, hexKey: string, now: number): Chest | null {
  if (world.chests.has(id)) return null;
  const qr = parseHexKey(hexKey);
  if (!qr) return null;
  const c = hexCenter(qr.q, qr.r);
  const chest: Chest = { id, hexKey, pos: { x: c.x, y: c.y }, spawnedAt: now };
  world.chests.set(id, chest);
  return chest;
}

/**
 * stepChests — the spawn cadence: every CHEST_SPAWN_INTERVAL_MS per in-run player
 * ("near activity"), a seeded hex within [CHEST_SPAWN_MIN_M, CHEST_SPAWN_RADIUS_M]
 * gets a chest, capped at CHEST_MAX_NEARBY unopened nearby. Also culls opened
 * chests after their linger window.
 */
export function stepChests(world: World, _dtMs: number, now: number): void {
  const next = stamps(world);
  for (const player of [...world.players.values()].sort((a, b) => (a.id < b.id ? -1 : 1))) {
    if (player.connId === null || player.run === null) continue;
    const at = next.get(player.id);
    if (at === undefined) {
      next.set(player.id, now + CHEST_SPAWN_INTERVAL_MS);
      continue;
    }
    if (now < at) continue;
    next.set(player.id, now + CHEST_SPAWN_INTERVAL_MS);

    let nearby = 0;
    for (const c of world.chests.values()) {
      if (c.openedBy === undefined && within(c.pos, player.pos, CHEST_NOTIFY_RADIUS_M)) nearby += 1;
    }
    if (nearby >= CHEST_MAX_NEARBY) continue;

    const candidates = hexKeysWithin(player.pos, CHEST_SPAWN_RADIUS_M)
      .filter((key) => {
        const qr = parseHexKey(key);
        if (!qr) return false;
        const c = hexCenter(qr.q, qr.r);
        if (distM(c, player.pos) < CHEST_SPAWN_MIN_M) return false;
        for (const ch of world.chests.values()) if (ch.hexKey === key) return false;
        return true;
      })
      .sort();
    if (candidates.length === 0) continue;
    const rng = seededRng(world.seed, 'chest-spawn', player.id, world.tick);
    const chest = spawnChest(world, `ch:${player.id}:${world.tick}`, rng.pick(candidates), now);
    if (chest) {
      // §13 chest-spawned-nearby trigger (the push edge reads this beat).
      pushGameEvents(world, player.id, now, [{ k: 'notice', text: 'a chest appeared nearby' }]);
    }
  }

  const opened = openedStamps(world);
  for (const chest of [...world.chests.values()]) {
    if (chest.openedBy === undefined) continue;
    const t = opened.get(chest.id);
    if (t === undefined) {
      opened.set(chest.id, now); // also stamps freshly-loaded saves
      continue;
    }
    if (now - t >= CHEST_CULL_MS) {
      world.chests.delete(chest.id);
      opened.delete(chest.id);
    }
  }
}

export interface OpenChestCtx {
  now: number;
  rng: Rng;
  genId: (kind: string) => string;
}

/**
 * openChest — the CHEST_OPEN resolution: §6 proximity gate (≤10 m) + not-looted,
 * then the 3-item staged rarity roll (+gold/+XP through the canonical award path).
 * Returns [LOOT_RESULT, INVENTORY_UPDATE] or one ERR frame, zero mutation on ERR.
 * Rng draw order: 3 × (rarity, pick), then gold.
 */
export function openChest(
  world: World,
  player: Player,
  chestId: string,
  refOp: number,
  ctx: OpenChestCtx,
): ServerMsg[] {
  const now = ctx.now;
  const chest = world.chests.get(chestId);
  if (!chest) return [err(now, 'NOT_FOUND', 'no such chest', refOp)];
  if (chest.openedBy !== undefined) return [err(now, 'ILLEGAL_STATE', 'already looted', refOp)];
  if (!within(player.pos, chest.pos, CHEST_OPEN_RADIUS_M)) {
    return [err(now, 'OUT_OF_RANGE', 'move closer to open', refOp)];
  }
  chest.openedBy = player.id;
  openedStamps(world).set(chest.id, now);

  const rolls = rollChestLoot(ctx.rng);
  for (const roll of rolls) {
    const def = itemDef(roll.itemId);
    player.inventory.push({
      iid: ctx.genId('item'),
      itemId: roll.itemId,
      isNew: true,
      ...(def?.effect.charges !== undefined ? { charges: def.effect.charges } : {}),
    });
    if (player.run) player.run.lootItemIds.push(roll.itemId);
  }
  const gold = ctx.rng.int(CHEST_GOLD_MIN, CHEST_GOLD_MAX);
  grantGold(world, player, gold, now, 'chest');
  grantXp(world, player, CHEST_XP, now, 'chest');
  player.updatedAt = now;
  return [
    {
      op: OP.LOOT_RESULT,
      t: now,
      sourceId: chest.id,
      items: rolls.map((r) => ({ itemId: r.itemId, rarity: r.rarity })),
      gold,
      xp: CHEST_XP,
    },
    buildInventoryUpdate(player, now),
  ];
}

registerTicker('chests', stepChests);

// §1 front completion pays a Grumble Chest — territory emits the request, we honor it.
registerChestSpawner((world, frontId, hexKey, now) => {
  const chest = spawnChest(world, `ch:f:${frontId}:${world.tick}`, hexKey, now);
  if (chest) {
    pushGameEvents(world, 'all', now, [{ k: 'notice', text: 'a Grumble Chest appeared!' }]);
  }
});
