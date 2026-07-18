// Party (§12): seeded join codes, join/cap/leave flows, member-state wire, and
// the §5 revive-eligibility read the death flow consumes.

import { afterEach, describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import type { Conn } from '../../sim/commands.js';
import { OP } from '../../shared/protocol.js';
import type { PartyUpdateMsg, ServerMsg } from '../../shared/protocol.js';
import { PARTY_MAX, REVIVE_RADIUS_M } from '../../shared/tuning.js';
import { registerCombatProbe } from '../../sim/systems/territory.js';
import { buildPartyUpdate, reviveEligible } from '../../sim/systems/party.js';

afterEach(() => registerCombatProbe(null));

function setup() {
  const h = SimHarness.create({ seed: 'party-test' });
  const { player, conn } = h.join('leader');
  return { h, player, conn };
}

function create(h: SimHarness, conn: Conn): ServerMsg[] {
  return h.apply({ op: OP.PARTY_CREATE, t: h.clock.now() }, conn);
}

function joinByCode(h: SimHarness, conn: Conn, code: string): ServerMsg[] {
  return h.apply({ op: OP.PARTY_JOIN, t: h.clock.now(), code }, conn);
}

function leave(h: SimHarness, conn: Conn): ServerMsg[] {
  return h.apply({ op: OP.PARTY_LEAVE, t: h.clock.now() }, conn);
}

describe('PARTY_CREATE', () => {
  it('mints a BONK-style code, replies PARTY_UPDATE, and is one-per-player', () => {
    const { h, player, conn } = setup();
    const frames = create(h, conn);
    const update = frames[0] as PartyUpdateMsg;
    expect(update.op).toBe(OP.PARTY_UPDATE);
    const party = update.party!;
    expect(party.code).toMatch(/^[A-Z]{3,4}-\d{4}$/);
    expect(party.leaderId).toBe(player.id);
    expect(party.members.map((m) => m.id)).toEqual([player.id]);
    expect(player.partyId).toBe(party.id);
    expect(create(h, conn)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });
});

describe('PARTY_JOIN', () => {
  it('joins by code (case-insensitive) and fans PARTY_UPDATE to sitting members', () => {
    const { h, player, conn } = setup();
    const code = (create(h, conn)[0] as PartyUpdateMsg).party!.code;
    h.drain();

    const p2 = h.join('friend');
    const frames = joinByCode(h, p2.conn, code.toLowerCase());
    const update = frames[0] as PartyUpdateMsg;
    expect(update.party!.members).toHaveLength(2);
    expect(p2.player.partyId).toBe(player.partyId);

    const fanned = h.drain().filter((e) => e.msg.op === OP.PARTY_UPDATE);
    expect(fanned.map((e) => e.to)).toEqual([player.id]); // joiner got the direct reply instead
  });

  it('bad code → NOT_FOUND; already partied → ILLEGAL_STATE; 5th member → CAP_REACHED', () => {
    const { h, conn } = setup();
    const code = (create(h, conn)[0] as PartyUpdateMsg).party!.code;
    expect(joinByCode(h, h.join('solo').conn, 'BONK-0000')[0]).toMatchObject({
      op: OP.ERR,
      code: 'NOT_FOUND',
    });
    expect(joinByCode(h, conn, code)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });

    for (let i = 2; i <= PARTY_MAX; i++) {
      const member = h.join(`m${i}`);
      expect(joinByCode(h, member.conn, code)[0].op).toBe(OP.PARTY_UPDATE);
    }
    const fifth = h.join('fifth');
    expect(joinByCode(h, fifth.conn, code)[0]).toMatchObject({ op: OP.ERR, code: 'CAP_REACHED' });
    expect(fifth.player.partyId).toBeNull();
  });
});

describe('PARTY_LEAVE', () => {
  it('hands leadership on, updates the survivors, dissolves when empty', () => {
    const { h, player, conn } = setup();
    const code = (create(h, conn)[0] as PartyUpdateMsg).party!.code;
    const p2 = h.join('heir');
    joinByCode(h, p2.conn, code);
    h.drain();

    const frames = leave(h, conn); // the leader walks
    expect((frames[0] as PartyUpdateMsg).party).toBeNull();
    expect(player.partyId).toBeNull();

    const survivors = h.drain().filter((e) => e.msg.op === OP.PARTY_UPDATE);
    expect(survivors.map((e) => e.to)).toEqual([p2.player.id]);
    const wire = (survivors[0].msg as PartyUpdateMsg).party!;
    expect(wire.leaderId).toBe(p2.player.id);
    expect(wire.members).toHaveLength(1);

    leave(h, p2.conn); // last one out
    expect(h.world.parties.size).toBe(0);
    expect(leave(h, p2.conn)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });
});

describe('member states (§12 wire)', () => {
  it('reads online / offline from the conn binding and inCombat from the combat probe', () => {
    const { h, player, conn } = setup();
    const code = (create(h, conn)[0] as PartyUpdateMsg).party!.code;
    const p2 = h.join('flaky');
    joinByCode(h, p2.conn, code);
    const party = h.world.parties.get(player.partyId!)!;

    p2.player.connId = null; // dropped socket
    let states = buildPartyUpdate(h.world, party, h.clock.now()).party!.members.map((m) => m.state);
    expect(states).toEqual(['online', 'offline']);

    registerCombatProbe((_w, p) => p.id === player.id);
    states = buildPartyUpdate(h.world, party, h.clock.now()).party!.members.map((m) => m.state);
    expect(states).toEqual(['inCombat', 'offline']);
  });
});

describe('revive eligibility (§5 consumer)', () => {
  it('true only with an online, alive party member within 30 m', () => {
    const { h, player, conn } = setup();
    expect(reviveEligible(h.world, player)).toBe(false); // no party

    const code = (create(h, conn)[0] as PartyUpdateMsg).party!.code;
    const p2 = h.join('medic');
    joinByCode(h, p2.conn, code);

    player.lifeState = 'downed';
    h.teleport(p2.player, REVIVE_RADIUS_M - 1, 0);
    expect(reviveEligible(h.world, player)).toBe(true);

    h.teleport(p2.player, REVIVE_RADIUS_M + 20, 0);
    expect(reviveEligible(h.world, player)).toBe(false);

    h.teleport(p2.player, 0, 0);
    p2.player.connId = null; // offline allies can't walk to you
    expect(reviveEligible(h.world, player)).toBe(false);
    p2.player.connId = 'c';
    p2.player.lifeState = 'downed'; // both down — nobody revives anybody
    expect(reviveEligible(h.world, player)).toBe(false);
  });
});
