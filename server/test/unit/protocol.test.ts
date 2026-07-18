import { describe, expect, it } from 'vitest';
import type { ClientMsg } from '../../shared/protocol.js';
import { OP, PROTOCOL_VERSION, decodeClient, encode } from '../../shared/protocol.js';

// One sample per client op — the roundtrip corpus.
const SAMPLES: ClientMsg[] = [
  { op: OP.JOIN, t: 1, seq: 0, protocolVersion: PROTOCOL_VERSION, gamertag: 'BONKLORD', characterId: 'knight' },
  { op: OP.RESUME, t: 2, protocolVersion: PROTOCOL_VERSION, sessionToken: 'tok-abc' },
  { op: OP.GPS, t: 3, lat: 40.2338, lng: -111.6585, accuracy: 8, heading: 90, speedKmh: 4.2, steps: 1204 },
  { op: OP.ATTACK, t: 4, mobId: 'mob-1' },
  { op: OP.USE_SLOT, t: 5, slot: 2, mobId: 'mob-1' },
  { op: OP.FLEE, t: 6 },
  { op: OP.EQUIP, t: 7, slot: 4, iid: 'inst-9' },
  { op: OP.EQUIP_GEAR, t: 8, gearSlot: 'helm', iid: null },
  { op: OP.BUY, t: 9, itemId: 'thwack_o_matic' },
  { op: OP.SELL, t: 10, iid: 'inst-3' },
  { op: OP.TOWER_BUILD, t: 11, type: 'bonk_turret', hexKey: '4,-2' },
  { op: OP.TOWER_REPAIR, t: 12, towerId: 'tw-1' },
  { op: OP.TOWER_UPGRADE, t: 13, towerId: 'tw-1' },
  { op: OP.TOWER_SALVAGE, t: 14, towerId: 'tw-2' },
  { op: OP.TOWER_TARGET, t: 15, towerId: 'tw-1', priority: 'guard_home' },
  { op: OP.TOWER_REPAIR_ALL, t: 16 },
  { op: OP.MINION_SEND, t: 17, minionId: 'mn-1', jobId: 'scout_front', frontId: 'front-3-1' },
  { op: OP.MINION_COLLECT, t: 18, minionId: 'mn-1' },
  { op: OP.MINION_HIRE, t: 19 },
  { op: OP.MINION_HEAL, t: 20, minionId: 'mn-2' },
  { op: OP.QUEST_CLAIM, t: 21, questId: 'daily_walk' },
  { op: OP.CHEST_OPEN, t: 22, chestId: 'ch-1' },
  { op: OP.PARTY_CREATE, t: 23 },
  { op: OP.PARTY_JOIN, t: 24, code: 'BONK-4242' },
  { op: OP.PARTY_LEAVE, t: 25 },
  { op: OP.RUN_START, t: 26 },
  { op: OP.RUN_END, t: 27 },
  { op: OP.RESPAWN, t: 28 },
  { op: OP.REVIVE, t: 29, playerId: 'pl-2' },
  { op: OP.REQUEST_SNAPSHOT, t: 30 },
  { op: OP.PONG, t: 31 },
];

describe('protocol codec', () => {
  it('covers every client op', () => {
    const clientOps = Object.values(OP).filter((v): v is number => typeof v === 'number' && v < 100);
    expect(new Set(SAMPLES.map((m) => m.op))).toEqual(new Set(clientOps));
  });

  it('encode/decode roundtrips every client op', () => {
    for (const msg of SAMPLES) {
      expect(decodeClient(encode(msg))).toEqual(msg);
    }
  });

  it('rejects malformed payloads', () => {
    // missing required field
    expect(() => decodeClient(JSON.stringify({ op: OP.GPS, t: 1, lat: 40 }))).toThrow();
    // out-of-range values
    expect(() => decodeClient(JSON.stringify({ op: OP.USE_SLOT, t: 1, slot: 7 }))).toThrow();
    expect(() => decodeClient(JSON.stringify({ op: OP.GPS, t: 1, lat: 999, lng: 0, accuracy: 5 }))).toThrow();
    // wrong type
    expect(() => decodeClient(JSON.stringify({ op: OP.ATTACK, t: 'now' }))).toThrow();
    // bad enum member
    expect(() => decodeClient(JSON.stringify({ op: OP.TOWER_BUILD, t: 1, type: 'laser_turret', hexKey: '0,0' }))).toThrow();
    // not JSON at all
    expect(() => decodeClient('not json')).toThrow();
  });

  it('rejects unknown / server-only / missing ops', () => {
    expect(() => decodeClient(JSON.stringify({ op: 39, t: 1 }))).toThrow();
    expect(() => decodeClient(JSON.stringify({ op: OP.SNAPSHOT, t: 1 }))).toThrow();
    expect(() => decodeClient(JSON.stringify({ t: 1 }))).toThrow();
  });

  it('strips unknown keys (forward-compatible additive fields)', () => {
    const decoded = decodeClient(JSON.stringify({ op: OP.FLEE, t: 1, futureField: true }));
    expect(decoded).toEqual({ op: OP.FLEE, t: 1 });
  });

  it('op numbers stay in their reserved bands', () => {
    for (const [name, v] of Object.entries(OP)) {
      if (typeof v !== 'number') continue;
      const clientSide = SAMPLES.some((m) => m.op === v);
      if (clientSide) expect(v, name).toBeLessThanOrEqual(39);
      else {
        expect(v, name).toBeGreaterThanOrEqual(100);
        expect(v, name).toBeLessThanOrEqual(139);
      }
    }
  });
});
