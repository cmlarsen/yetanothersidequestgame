// Persistence round-trip (DESIGN §Persistence): save() splits serialize() into
// rows, load() reassembles + deserializes — so save → load → serialize must be
// byte-identical on every persisted field, neutral hexes must carry no rows, and
// runtime state must come back reset.

import { describe, expect, it } from 'vitest';
import { SimHarness } from '../harness/sim-harness.js';
import { openDb, type Db } from '../../persistence/db.js';
import { load, save } from '../../persistence/repo.js';
import { serialize } from '../../sim/world.js';
import { claimHexForPlayer, setHexOwner } from '../../sim/systems/territory.js';
import type { Player, Tower } from '../../shared/entities.js';

function count(db: Db, table: string): number {
  return (db.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get() as { n: number }).n;
}

/** A world with every persisted entity kind touched. */
function scenario() {
  const h = SimHarness.create({ seed: 'roundtrip' });
  const { player, conn } = h.join('Keeper');
  h.runStart(conn);
  h.tick(1); // claim 0,0 through the real enter path (front + area xp + home anchor)
  const now = h.clock.now();
  claimHexForPlayer(h.world, player, '1,0', now);
  claimHexForPlayer(h.world, player, '0,1', now);
  setHexOwner(h.world, '5,5', 'gloom', now);

  const tower: Tower = {
    id: 'tower_1',
    ownerId: player.id,
    type: 'bonk_turret',
    hexKey: '1,0',
    level: 2,
    durability: 87.5,
    targetPriority: 'guard_home',
    isRubble: false,
    builtAt: now,
    log: [{ at: now, event: 'built' }],
  };
  h.world.towers.set(tower.id, tower);
  h.world.hexes.get('1,0')!.towerId = tower.id;

  const roster = h.world.minions.get(player.id)!;
  roster[0].state = 'on_job';
  roster[0].job = { jobId: 'gather_lumber', startedAt: now, endsAt: now + 1_800_000, riskPct: 0 };

  h.world.parties.set('party_1', {
    id: 'party_1',
    code: 'BONK-4242',
    leaderId: player.id,
    memberIds: [player.id],
    createdAt: now,
  });
  player.partyId = 'party_1';

  h.world.chests.set('chest_1', {
    id: 'chest_1',
    hexKey: '0,0',
    pos: { x: 1, y: 2 },
    spawnedAt: now,
    openedBy: player.id,
  });
  h.world.goldDrops.set('gd_1', {
    id: 'gd_1',
    ownerId: player.id,
    pos: { x: 3, y: 4 },
    hexKey: '0,0',
    gold: 75,
    droppedAt: now,
    expiresAt: now + 3_600_000,
  });

  const front = h.world.fronts.get('f0,0')!;
  front.gloomAccum = 1.25;
  front.scoutIntel = { pushEta: now + 60_000, scoutedAt: now };

  const questId = Object.keys(player.quests).sort()[0];
  player.quests[questId].progress = 3;
  player.quests[questId].state = 'claimable';
  player.updatedAt = now;

  return { h, player, conn };
}

describe('save → load round-trip', () => {
  it('re-serializes byte-identically on every persisted field', () => {
    const { h } = scenario();
    const db = openDb(':memory:');
    save(db, h.world);
    const loaded = load(db);
    expect(loaded).not.toBeNull();
    expect(serialize(loaded!)).toBe(h.serialize());
  });

  it('is idempotent across repeated saves and persists world.tick', () => {
    const { h } = scenario();
    const db = openDb(':memory:');
    save(db, h.world);
    h.tick(3);
    save(db, h.world);
    save(db, h.world);
    expect(count(db, 'world_meta')).toBe(1);
    const loaded = load(db)!;
    expect(loaded.tick).toBe(h.world.tick);
    expect(serialize(loaded)).toBe(h.serialize());
  });

  it('returns null from an empty database', () => {
    const db = openDb(':memory:');
    expect(load(db)).toBeNull();
  });
});

describe('row-set minimality', () => {
  it('only non-neutral hexes get rows; owners are never neutral', () => {
    const { h } = scenario();
    const db = openDb(':memory:');
    save(db, h.world);
    expect(count(db, 'hex')).toBe(h.world.hexes.size); // world.hexes IS the non-neutral set
    const owners = db.prepare('SELECT DISTINCT owner FROM hex ORDER BY owner').all() as {
      owner: string;
    }[];
    expect(owners.map((o) => o.owner)).toEqual(['gloom', 'players']);
  });

  it('unopened chests carry no row and are treated as re-derivable', () => {
    const { h } = scenario();
    const now = h.clock.now();
    h.world.chests.set('chest_2', { id: 'chest_2', hexKey: '1,0', pos: { x: 9, y: 9 }, spawnedAt: now });
    const db = openDb(':memory:');
    save(db, h.world);
    expect(count(db, 'chest_state')).toBe(1); // the opened one only
    const loaded = load(db)!;
    expect(loaded.chests.has('chest_1')).toBe(true);
    expect(loaded.chests.has('chest_2')).toBe(false);
  });

  it('prunes rows for entities that left the persisted set', () => {
    const { h, player } = scenario();
    const db = openDb(':memory:');
    save(db, h.world);
    expect(count(db, 'tower')).toBe(1);
    const hexCount = count(db, 'hex');
    h.world.towers.delete('tower_1'); // salvaged
    delete h.world.hexes.get('1,0')!.towerId;
    h.world.hexes.delete('0,1'); // hypothetical back-to-neutral: row must not linger
    h.world.parties.delete('party_1');
    player.partyId = null;
    save(db, h.world);
    expect(count(db, 'tower')).toBe(0);
    expect(count(db, 'hex')).toBe(hexCount - 1);
    expect(count(db, 'party')).toBe(0);
    expect(serialize(load(db)!)).toBe(h.serialize());
  });

  it('writes the quest projection one row per (player, quest), in step with the blob', () => {
    const { h, player } = scenario();
    const db = openDb(':memory:');
    save(db, h.world);
    expect(count(db, 'quest_state')).toBe(Object.keys(player.quests).length);
    const claimable = db
      .prepare("SELECT quest_id FROM quest_state WHERE state = 'claimable'")
      .all() as { quest_id: string }[];
    expect(claimable.map((r) => r.quest_id)).toEqual([Object.keys(player.quests).sort()[0]]);
    const loaded = load(db)!;
    const lp = loaded.players.get(player.id)!;
    expect(lp.quests).toEqual(player.quests);
  });
});

describe('runtime reset on load', () => {
  it('conn binding, life state, run/death machines, and cooldowns all reset', () => {
    const { h, player } = scenario();
    // dirty every runtime field before saving
    player.connId = 'conn_live';
    player.lifeState = 'downed';
    player.death = { diedAt: 1, at: { x: 0, y: 0 }, reviveDeadline: 2, goldDropId: null };
    player.moveTarget = { x: 9, y: 9 };
    player.speedKmh = 12;
    player.gpsAccuracy = 8;
    player.slotReadyAt = [1, 2, 3, 4, 5];
    expect(player.run).not.toBeNull(); // the scenario's run is still active

    const db = openDb(':memory:');
    save(db, h.world);
    const lp = (load(db)!.players.get(player.id) as Player | undefined)!;
    expect(lp.connId).toBeNull();
    expect(lp.lifeState).toBe('alive');
    expect(lp.death).toBeNull();
    expect(lp.run).toBeNull();
    expect(lp.moveTarget).toBeNull();
    expect(lp.speedKmh).toBe(0);
    expect(lp.gpsAccuracy).toBe(0);
    expect(lp.slotReadyAt).toEqual([0, 0, 0, 0, 0]);
    // ...while the persisted scalars survive
    expect(lp.gold).toBe(player.gold);
    expect(lp.level).toBe(player.level);
    expect(lp.homeHex).toBe('0,0');
    expect(lp.partyId).toBe('party_1');
  });
});
