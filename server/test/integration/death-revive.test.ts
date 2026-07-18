// Integration (d): the full §5 death loop driven by REAL combat retaliation —
// penalties (gold drop + contested-hex loss), RESPAWN back at the home hex, and a
// party member walking in to REVIVE inside the 60 s window. Party formation goes
// through the real PARTY_CREATE/PARTY_JOIN commands.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js';
import '../../sim/commands_economy.js';
import { SimHarness, type JoinedPlayer } from '../harness/sim-harness.js';
import { makeMob } from '../../sim/systems/mobs.js';
import { MOB_FIRST_SWING_DELAY_MS } from '../../sim/systems/combat.js';
import { setHexOwner } from '../../sim/systems/territory.js';
import { hexCenter } from '../../shared/hexgrid.js';
import { OP } from '../../shared/protocol.js';
import type { DeathMsg, PartyUpdateMsg } from '../../shared/protocol.js';
import { REVIVE_COUNTDOWN_SEC, REVIVE_RADIUS_M, deathGoldDrop } from '../../shared/tuning.js';

const SWING_TICKS = Math.ceil(MOB_FIRST_SWING_DELAY_MS / 100) + 1;

function setup() {
  const h = SimHarness.create({ seed: 'death-int' });
  const a = h.join('fighter');
  const b = h.join('medic');
  h.runStart(a.conn);
  h.tick(1); // fighter claims 0,0 → home hex
  return { h, a, b };
}

/** Enter the gloom hex 1,0 (contested), kill its defender → a contested-won claim. */
function winContestedHex(h: SimHarness, a: JoinedPlayer): void {
  setHexOwner(h.world, '1,0', 'gloom', h.clock.now());
  const c = hexCenter(1, 0);
  h.teleport(a.player, c.x, c.y);
  h.tick(1); // territory marks CONTESTED, combat hook spawns + engages the defender
  const defender = h.world.mobs.get('mobd:1,0')!;
  defender.hp = 1;
  h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: defender.id }, a.conn);
  expect(h.world.hexes.get('1,0')!.owner).toBe('players');
  expect(a.player.run!.contestedClaimed).toContain('1,0');
}

/** Stand the fighter in a crafted brute's hex and let retaliation down them. */
function downFighter(h: SimHarness, a: JoinedPlayer): void {
  const mob = makeMob('brute', 'gloomling', hexCenter(2, 0));
  mob.hp = 100_000;
  mob.maxHp = 100_000;
  h.world.mobs.set(mob.id, mob);
  const c = hexCenter(2, 0);
  h.teleport(a.player, c.x, c.y);
  h.tick(1); // enters the hex → auto-engage (§3)
  a.player.hp = 1; // next swing downs
  h.tick(SWING_TICKS);
  expect(a.player.lifeState).toBe('downed');
}

describe('death penalties + respawn home (§5)', () => {
  it('downing pays the gold + contested-hex penalties; RESPAWN returns home at full HP', () => {
    const { h, a } = setup();
    a.player.gold = 800;
    winContestedHex(h, a);
    const goldBefore = a.player.gold; // 800 + the defender kill's gold reward
    h.drain();
    downFighter(h, a);

    // penalties: gold drop max(50, 10%) lands on the map, contested win flips back
    const mine = h.drain().filter((e) => e.to === a.player.id);
    const death = mine.find((e) => e.msg.op === OP.DEATH)!.msg as DeathMsg;
    expect(death.goldDropped).toBe(deathGoldDrop(goldBefore));
    expect(death.hexesLost).toEqual(['1,0']);
    expect(a.player.gold).toBe(goldBefore - death.goldDropped);
    expect(h.world.hexes.get('1,0')!.owner).toBe('gloom');
    expect(mine.some((e) => e.msg.op === OP.RUN_SUMMARY)).toBe(true);
    expect(a.player.run).toBeNull();
    const drop = [...h.world.goldDrops.values()][0];
    expect(drop.ownerId).toBe(a.player.id);
    expect(drop.gold).toBe(death.goldDropped);

    // downed: combat refuses, RESPAWN is the door home
    const denied = h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: 'brute' }, a.conn);
    expect(denied[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });

    const frames = h.apply({ op: OP.RESPAWN, t: h.clock.now() }, a.conn);
    expect(frames[0].op).toBe(OP.SNAPSHOT);
    const home = hexCenter(0, 0);
    expect(a.player.pos).toEqual({ x: home.x, y: home.y });
    expect(a.player.hp).toBe(a.player.maxHp);
    expect(a.player.lifeState).toBe('alive');
  });

  it('the revive window lapsing auto-respawns at home on tick', () => {
    const { h, a } = setup();
    a.player.gold = 100;
    downFighter(h, a);
    h.tick(REVIVE_COUNTDOWN_SEC * 10 + 2); // 60 s at 10 Hz
    expect(a.player.lifeState).toBe('alive');
    expect(a.player.pos.x).toBeCloseTo(hexCenter(0, 0).x, 6);
  });
});

describe('party revive (§5/§12)', () => {
  it('a party member within 30 m revives the downed fighter in place', () => {
    const { h, a, b } = setup();
    a.player.gold = 100;

    // real party formation: create → join by code
    const created = h.apply({ op: OP.PARTY_CREATE, t: h.clock.now() }, a.conn);
    const party = (created[0] as PartyUpdateMsg).party!;
    expect(party.code).toMatch(/^[A-Z]+-\d{4}$/);
    const joined = h.apply({ op: OP.PARTY_JOIN, t: h.clock.now(), code: party.code }, b.conn);
    expect((joined[0] as PartyUpdateMsg).party!.members).toHaveLength(2);

    downFighter(h, a);
    const deathPos = { x: a.player.pos.x, y: a.player.pos.y };

    // out of range first
    h.teleport(b.player, deathPos.x + REVIVE_RADIUS_M + 50, deathPos.y);
    const far = h.apply({ op: OP.REVIVE, t: h.clock.now(), playerId: a.player.id }, b.conn);
    expect(far[0]).toMatchObject({ op: OP.ERR, code: 'OUT_OF_RANGE' });

    // walk in → revive: alive, full HP, in place (not teleported home)
    h.teleport(b.player, deathPos.x + 10, deathPos.y);
    expect(h.apply({ op: OP.REVIVE, t: h.clock.now(), playerId: a.player.id }, b.conn)).toEqual([]);
    expect(a.player.lifeState).toBe('alive');
    expect(a.player.hp).toBe(a.player.maxHp);
    expect(a.player.pos).toEqual(deathPos);
    const beats = h
      .drain()
      .flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []));
    expect(beats.some((ev) => ev.k === 'revive' && ev.playerId === a.player.id)).toBe(true);
  });

  it('revive refuses without a shared party', () => {
    const { h, a, b } = setup();
    a.player.gold = 100;
    downFighter(h, a);
    h.teleport(b.player, a.player.pos.x + 5, a.player.pos.y);
    const stranger = h.apply({ op: OP.REVIVE, t: h.clock.now(), playerId: a.player.id }, b.conn);
    expect(stranger[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });
});
