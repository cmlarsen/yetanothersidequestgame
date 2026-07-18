// Combat (§3): affinity/crit math, cooldown + charge gating, tyrant segments,
// retaliation + block/reflect, flee boundary, victory settlement (hex flip, shared
// credit, deterministic drops), death → §5 penalties + revive window, op validation.
// Crafted mobs are inserted directly into world.mobs (no GPS ⇒ no ambient field),
// so every scenario is fully controlled.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js';
import { SimHarness } from '../harness/sim-harness.js';
import type { JoinedPlayer } from '../harness/sim-harness.js';
import { makeMob, mobGoldReward, mobMaxHp, mobXpReward } from '../../sim/systems/mobs.js';
import { MOB_FIRST_SWING_DELAY_MS, MOB_SWING_COOLDOWN_MS } from '../../sim/systems/combat.js';
import { setHexOwner } from '../../sim/systems/territory.js';
import { rollMobDrop } from '../../sim/systems/loot.js';
import { hexCenter } from '../../shared/hexgrid.js';
import { seededRng } from '../../shared/rng.js';
import { OP } from '../../shared/protocol.js';
import type { DeathMsg, EventsMsg, GameEvent, LootResultMsg } from '../../shared/protocol.js';
import { ITEMS, MOBS } from '../../shared/catalog.js';
import { SPEED_PAUSE_KMH, WEAK_MULTIPLIER } from '../../shared/tuning.js';

function setup(seed = 'combat-test') {
  const h = SimHarness.create({ seed });
  const jp = h.join('fighter');
  h.runStart(jp.conn);
  h.tick(1); // claims 0,0 (home), pays NEW AREA xp
  return { h, ...jp };
}

/** Craft a mob at hex (q,r) and (optionally) paint the hex gloom first. */
function placeMob(
  h: SimHarness,
  id: string,
  species: 'gloomling' | 'grumbleshroom',
  q: number,
  r: number,
  opts: { gloom?: boolean; hp?: number } = {},
) {
  if (opts.gloom) setHexOwner(h.world, `${q},${r}`, 'gloom', h.clock.now());
  const mob = makeMob(id, species, hexCenter(q, r));
  if (opts.hp !== undefined) {
    mob.hp = opts.hp;
    mob.maxHp = Math.max(mob.maxHp, opts.hp);
  }
  h.world.mobs.set(id, mob);
  return mob;
}

function gameEvents(h: SimHarness): GameEvent[] {
  return h
    .drain()
    .flatMap((e) => (e.msg.op === OP.EVENTS ? (e.msg as EventsMsg).events : []));
}

describe('hotbar slot resolution (§3)', () => {
  it('weapon vs weak mob: ×1.5 affinity, no cooldown, deterministic per seed', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.drain();
    const frames = h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    expect(frames).toEqual([]); // events ride the outbox
    const hits = gameEvents(h).filter((e) => e.k === 'hit');
    expect(hits).toHaveLength(1);
    const hit = hits[0] as Extract<GameEvent, { k: 'hit' }>;
    expect(hit.by).toBe(player.id);
    expect(hit.mult).toBe(WEAK_MULTIPLIER); // gloomling is weak to BONK
    expect(hit.kb).toBe(ITEMS.bonk_hammer.effect.knockbackHexes); // knockback flavor, set bonus inactive
    // base 24 + atk 0, ×1.5 → 36 (72 on crit); exact value pinned for this seed
    expect([36, 72]).toContain(hit.dmg);
    expect(hit.dmg).toBe(36);
    // determinism: an identical world + script lands the identical hit
    const b = setup();
    placeMob(b.h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    b.h.drain();
    b.h.apply({ op: OP.ATTACK, t: b.h.clock.now(), mobId: 'm1' }, b.conn);
    const bHit = gameEvents(b.h).filter((e) => e.k === 'hit')[0] as typeof hit;
    expect(bHit.dmg).toBe(hit.dmg);
    expect(bHit.crit).toBe(hit.crit);
  });

  it('spell vs resistant mob: ×0.5 affinity', () => {
    const { h, conn } = setup();
    placeMob(h, 'boss', 'grumbleshroom', 1, 0, { hp: 10_000 });
    h.drain();
    h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 1, mobId: 'boss' }, conn); // zap_scroll
    const hit = gameEvents(h).filter((e) => e.k === 'hit')[0] as Extract<GameEvent, { k: 'hit' }>;
    expect(hit.mult).toBe(0.5); // grumbleshroom resists ZAP
    // base 12 + atk 0, ×0.5 → 6 (12 on crit)
    expect([6, 12]).toContain(hit.dmg);
  });

  it('spell cooldown gates by readyAt stamp (ON_COOLDOWN), reopens after the window', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    player.hp = 1_000; // survive retaliation while the clock runs
    h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 1, mobId: 'm1' }, conn);
    const again = h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 1, mobId: 'm1' }, conn);
    expect(again[0]).toMatchObject({ op: OP.ERR, code: 'ON_COOLDOWN' });
    h.tick(Math.ceil((ITEMS.zap_scroll.effect.cooldownSec! * 1000) / 100) + 1);
    const after = h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 1, mobId: 'm1' }, conn);
    expect(after).toEqual([]);
  });

  it('consumable decrements charges, heals, and refuses when empty', () => {
    const { h, player, conn } = setup();
    player.hp = 1;
    const frames = h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 3 }, conn); // fizzy_mender
    expect(frames[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(player.hp).toBe(Math.min(player.maxHp, 1 + ITEMS.fizzy_mender.effect.healHp!));
    const inst = player.inventory.find((i) => i.iid === player.hotbar[3])!;
    expect(inst.charges).toBe(2);
    player.hp = 1;
    h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 3 }, conn);
    h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 3 }, conn);
    expect(inst.charges).toBe(0);
    const empty = h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 3 }, conn);
    expect(empty[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });

  it('empty slot and level-locked items refuse', () => {
    const { h, player, conn } = setup();
    const empty = h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 4 }, conn);
    expect(empty[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    player.inventory.push({ iid: 'pb1', itemId: 'pocket_blizzard', isNew: false });
    player.hotbar[4] = 'pb1';
    const locked = h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 4 }, conn);
    expect(locked[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });
});

describe('tyrant segments (§3)', () => {
  it('grumbleshroom carries 4 segments of HP', () => {
    const boss = makeMob('boss', 'grumbleshroom', hexCenter(1, 0));
    expect(boss.maxHp).toBe(mobMaxHp('grumbleshroom'));
    expect(boss.maxHp % MOBS.grumbleshroom.hpSegments).toBe(0);
    expect(boss.maxHp / MOBS.grumbleshroom.hpSegments).toBe(70);
  });
});

describe('retaliation + block (§3)', () => {
  it('an engaged mob swings on cooldown; damage is swing − DEF (floor 1)', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    const hpBefore = player.hp;
    h.tick(Math.ceil(MOB_FIRST_SWING_DELAY_MS / 100) + 1);
    // gloomling swing 4+2×3 = 10, player DEF 5 → 5 dealt
    expect(player.hp).toBe(hpBefore - 5);
    h.tick(Math.ceil(MOB_SWING_COOLDOWN_MS / 100) + 1);
    expect(player.hp).toBe(hpBefore - 10);
  });

  it('Turtle Up blocks all damage and reflects 20%', () => {
    const { h, player, conn } = setup();
    const mob = placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    h.apply({ op: OP.USE_SLOT, t: h.clock.now(), slot: 2 }, conn); // turtle_up: block 3 s
    const hpBefore = player.hp;
    const mobHpBefore = mob.hp;
    h.drain();
    h.tick(Math.ceil(MOB_FIRST_SWING_DELAY_MS / 100) + 1); // swing lands inside the block
    expect(player.hp).toBe(hpBefore);
    expect(mob.hp).toBe(mobHpBefore - 2); // reflect 20% of 10
    const beats = gameEvents(h);
    expect(beats.some((e) => e.k === 'player_hit' && e.dmg === 0)).toBe(true);
    expect(beats.some((e) => e.k === 'hit' && e.by === player.id && e.dmg === 2)).toBe(true);
  });
});

describe('flee boundary (§3)', () => {
  it('walking out past mob hex + 1-hex buffer disengages', () => {
    const { h, player, conn } = setup();
    const mob = placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    expect(mob.engagedBy).toEqual([player.id]);
    const far = hexCenter(3, 0); // hex distance 2 from the mob's hex
    h.teleport(player, far.x, far.y);
    h.tick(1);
    expect(mob.engagedBy).toEqual([]);
  });

  it('FLEE explicitly disengages; FLEE with no fight is illegal', () => {
    const { h, player, conn } = setup();
    const mob = placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    expect(h.apply({ op: OP.FLEE, t: h.clock.now() }, conn)).toEqual([]);
    expect(mob.engagedBy).toEqual([]);
    const noFight = h.apply({ op: OP.FLEE, t: h.clock.now() }, conn);
    expect(noFight[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });

  it('entering a mob\'s hex auto-engages (combat begins on entry, §3)', () => {
    const { h, player } = setup();
    const mob = placeMob(h, 'm1', 'gloomling', 2, 0, { hp: 10_000 });
    const c = hexCenter(2, 0);
    h.teleport(player, c.x, c.y);
    h.tick(1);
    expect(mob.engagedBy).toEqual([player.id]);
  });
});

describe('victory settlement (§3/§6)', () => {
  it('flips the hex, pays XP+gold, ticks run counters, emits kill + LOOT_RESULT', () => {
    const { h, player, conn } = setup();
    const mob = placeMob(h, 'm1', 'gloomling', 1, 0, { gloom: true, hp: 1 });
    h.drain();
    const xpBefore = player.xp;
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    expect(h.world.mobs.has('m1')).toBe(false);
    expect(h.world.hexes.get('1,0')?.owner).toBe('players');
    expect(h.world.hexes.get('1,0')?.contestedMobId).toBeUndefined();
    expect(player.run!.mobsDefeated).toBe(1);
    expect(player.run!.contestedClaimed).toContain('1,0');
    expect(player.xp).toBe(xpBefore + mobXpReward(mob));
    expect(player.gold).toBe(mobGoldReward(mob));
    expect(player.quests['daily_defeat'].progress).toBe(1);
    const out = h.drain();
    const beats = out.flatMap((e) => (e.msg.op === OP.EVENTS ? (e.msg as EventsMsg).events : []));
    expect(beats.some((e) => e.k === 'kill' && e.mobId === 'm1')).toBe(true);
    const loot = out.find((e) => e.to === player.id && e.msg.op === OP.LOOT_RESULT)!
      .msg as LootResultMsg;
    expect(loot.sourceId).toBe('m1');
    expect(loot.xp).toBe(mobXpReward(mob));
    expect(loot.gold).toBe(mobGoldReward(mob));
    // drop determinism: the settle path draws seededRng(seed, 'mob-drop', mob, player)
    const expected = rollMobDrop(seededRng(h.world.seed, 'mob-drop', 'm1', player.id), false);
    expect(loot.items).toEqual(
      expected ? [{ itemId: expected.itemId, rarity: expected.rarity }] : [],
    );
  });

  it('tyrants drop an item 100% of the time', () => {
    for (const seed of ['ty-a', 'ty-b', 'ty-c']) {
      const { h, player, conn } = setup(seed);
      placeMob(h, 'boss', 'grumbleshroom', 1, 0, { gloom: true, hp: 1 });
      h.drain();
      h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'boss' }, conn);
      const loot = h
        .drain()
        .find((e) => e.to === player.id && e.msg.op === OP.LOOT_RESULT)!.msg as LootResultMsg;
      expect(loot.items).toHaveLength(1);
      expect(player.quests['daily_defeat'].progress).toBe(0); // tyrant ≠ gloomling
    }
  });

  it('contested-hex entry spawns a defender; killing it settles the contest', () => {
    const { h, player, conn } = setup();
    setHexOwner(h.world, '1,0', 'gloom', h.clock.now());
    const c = hexCenter(1, 0);
    h.teleport(player, c.x, c.y);
    h.tick(1); // territory marks CONTESTED → combat hook spawns + engages the defender
    const hs = h.world.hexes.get('1,0')!;
    expect(hs.owner).toBe('gloom');
    expect(hs.contestedMobId).toBe('mobd:1,0');
    const mob = h.world.mobs.get('mobd:1,0')!;
    expect(mob.engagedBy).toEqual([player.id]);
    mob.hp = 1;
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: mob.id }, conn);
    expect(h.world.hexes.get('1,0')?.owner).toBe('players');
    expect(h.world.hexes.get('1,0')?.contestedMobId).toBeUndefined();
  });
});

describe('death & revive (§5)', () => {
  it('mob retaliation to 0 HP routes into applyDeath: DEATH frame + run ends', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    player.hp = 3; // next swing (5 dealt) downs the player
    h.drain();
    h.tick(Math.ceil(MOB_FIRST_SWING_DELAY_MS / 100) + 1);
    expect(player.lifeState).toBe('downed');
    expect(player.run).toBeNull();
    const mine = h.drain().filter((e) => e.to === player.id);
    const death = mine.find((e) => e.msg.op === OP.DEATH)?.msg as DeathMsg;
    expect(death).toBeDefined();
    expect(death.reviveDeadline).toBe(player.death!.reviveDeadline);
    expect(mine.some((e) => e.msg.op === OP.RUN_SUMMARY)).toBe(true);
  });

  it('a party member within 30 m can REVIVE inside the window', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    player.hp = 1;
    h.tick(Math.ceil(MOB_FIRST_SWING_DELAY_MS / 100) + 1);
    expect(player.lifeState).toBe('downed');
    const ally: JoinedPlayer = h.join('ally');
    player.partyId = 'pt1';
    ally.player.partyId = 'pt1';
    h.teleport(ally.player, player.pos.x + 10, player.pos.y);
    const frames = h.apply({ op: OP.REVIVE, t: h.clock.now(), playerId: player.id }, ally.conn);
    expect(frames).toEqual([]);
    expect(player.lifeState).toBe('alive');
    expect(player.hp).toBe(player.maxHp);
  });
});

describe('intent validation', () => {
  it('ATTACK out of range / unknown mob / no weapon', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'far', 'gloomling', 3, 0, { hp: 100 });
    const far = h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'far' }, conn);
    expect(far[0]).toMatchObject({ op: OP.ERR, code: 'OUT_OF_RANGE' });
    const none = h.apply({ op: OP.ATTACK, t: h.clock.now() }, conn);
    expect(none[0]).toMatchObject({ op: OP.ERR, code: 'OUT_OF_RANGE' });
    const unknown = h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'nope' }, conn);
    expect(unknown[0]).toMatchObject({ op: OP.ERR, code: 'NOT_FOUND' });
    player.hotbar[0] = null;
    const noWeapon = h.apply({ op: OP.ATTACK, t: h.clock.now() }, conn);
    expect(noWeapon[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });

  it('combat requires an active run and pauses above the driving speed (§2/§14)', () => {
    const h = SimHarness.create({ seed: 'combat-gate' });
    const { player, conn } = h.join('gated');
    placeMob(h, 'm1', 'gloomling', 0, 0, { hp: 100 });
    const noRun = h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    expect(noRun[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    h.runStart(conn);
    player.speedKmh = SPEED_PAUSE_KMH + 5;
    const fast = h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    expect(fast[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    player.speedKmh = 4;
    expect(h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn)).toEqual([]);
  });

  it('mid-run RUN_END while engaged is a retreat (combat probe wired)', () => {
    const { h, player, conn } = setup();
    placeMob(h, 'm1', 'gloomling', 1, 0, { hp: 10_000 });
    player.gold = 100;
    player.run!.goldAtStart = 100; // banked before the run's earnings
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'm1' }, conn);
    player.gold += 40; // "earned" mid-run
    const frames = h.runEnd(conn);
    expect(frames[0]).toMatchObject({ op: OP.RUN_SUMMARY, goldDropped: 40 });
  });
});
