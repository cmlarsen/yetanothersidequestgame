// Two-lane outbound (DESIGN §two-lane outbound): outbox events drain every tick
// routed by audience; DELTAs ride broadcast ticks only, fingerprint-gated per
// connection — no empty frames, removes when entities leave the window.

import { describe, expect, it } from 'vitest';
import { SimHarness } from '../harness/sim-harness.js';
import {
  computeDelta,
  newInterest,
  pumpOutbound,
  type OutboundConn,
  type SendFn,
} from '../../net/outbound.js';
import { pushGameEvents } from '../../sim/systems/outbox.js';
import { OP, OWNER_PLAYERS } from '../../shared/protocol.js';
import type { DeltaMsg, FrontUpdateMsg, ServerMsg } from '../../shared/protocol.js';
import { RELEVANCE_M } from '../../shared/constants.js';
import type { Tower } from '../../shared/entities.js';

function setup() {
  const h = SimHarness.create({ seed: 'outbound-test' });
  const { player, conn } = h.join('Scout');
  const view: OutboundConn = { connId: conn.connId, playerId: conn.playerId, interest: newInterest() };
  const sent: Array<{ connId: string; msg: ServerMsg }> = [];
  const send: SendFn = (connId, msg) => sent.push({ connId, msg });
  const pump = (tick: number): void => pumpOutbound(h.world, [view], tick, h.clock.now(), send);
  const deltas = (): DeltaMsg[] =>
    sent.filter((s) => s.msg.op === OP.DELTA).map((s) => s.msg as DeltaMsg);
  return { h, player, conn, view, sent, send, pump, deltas };
}

describe('DELTA fingerprints', () => {
  it('ships self on the first broadcast, then nothing while the world is quiet', () => {
    const { player, sent, pump, deltas } = setup();
    pump(2);
    expect(deltas()).toHaveLength(1);
    expect(deltas()[0].upserts.players?.map((p) => p.id)).toEqual([player.id]);
    sent.length = 0;
    pump(4);
    expect(sent).toEqual([]); // unchanged world ⇒ not even an empty frame
  });

  it('skips the delta lane entirely on non-broadcast ticks', () => {
    const { sent, pump } = setup();
    pump(3);
    expect(sent).toEqual([]);
  });

  it('a claimed hex rides as an upsert with a FRONT_UPDATE for its pct move', () => {
    const { h, conn, sent, pump, deltas } = setup();
    h.runStart(conn);
    h.tick(1); // enters 0,0 → claim + area/xp beats hit the outbox
    sent.length = 0;
    pump(2);
    expect(sent.some((s) => s.msg.op === OP.EVENTS)).toBe(true);
    const fronts = sent.filter((s) => s.msg.op === OP.FRONT_UPDATE).map((s) => s.msg as FrontUpdateMsg);
    expect(fronts).toHaveLength(1);
    expect(fronts[0].front.id).toBe('f0,0');
    expect(fronts[0].front.pctPlayer).toBe(2); // 1 of 64 hexes
    expect(deltas()[0].upserts.hexes).toEqual([{ k: '0,0', o: OWNER_PLAYERS, f: 'f0,0' }]);
    // everything fingerprinted — the next broadcast is silent
    sent.length = 0;
    pump(4);
    expect(sent).toEqual([]);
  });

  it('tower upserts re-ride only when durability/level move', () => {
    const { h, player, sent, pump, deltas } = setup();
    const now = h.clock.now();
    const tower: Tower = {
      id: 'tower_1',
      ownerId: player.id,
      type: 'bonk_turret',
      hexKey: '0,0',
      level: 1,
      durability: 100,
      targetPriority: 'nearest',
      isRubble: false,
      builtAt: now,
      log: [],
    };
    h.world.towers.set(tower.id, tower);
    pump(2);
    expect(deltas()[0].upserts.towers?.[0]).toMatchObject({ id: 'tower_1', dur: 100, lvl: 1 });
    sent.length = 0;
    pump(4);
    expect(sent).toEqual([]); // unchanged tower doesn't re-ride
    tower.durability = 63;
    pump(6);
    expect(deltas()[0].upserts.towers?.[0]).toMatchObject({ id: 'tower_1', dur: 63 });
  });
});

describe('window removes', () => {
  it('a player leaving the relevance window is removed, not silently dropped', () => {
    const { h, sent, pump, deltas } = setup();
    const rover = h.join('Rover'); // spawns at (0,0), inside the window
    pump(2);
    expect(deltas()[0].upserts.players?.map((p) => p.id)).toContain(rover.player.id);
    h.teleport(rover.player, RELEVANCE_M * 3, 0);
    sent.length = 0;
    pump(4);
    expect(deltas()).toHaveLength(1);
    expect(deltas()[0].removes.players).toEqual([rover.player.id]);
    expect(deltas()[0].upserts.players).toBeUndefined();
  });

  it('an opened chest is removed from every window', () => {
    const { h, player, sent, pump, deltas } = setup();
    const now = h.clock.now();
    h.world.chests.set('chest_1', { id: 'chest_1', hexKey: '0,0', pos: { x: 5, y: 5 }, spawnedAt: now });
    pump(2);
    expect(deltas()[0].upserts.chests?.map((c) => c.id)).toEqual(['chest_1']);
    h.world.chests.get('chest_1')!.openedBy = player.id;
    sent.length = 0;
    pump(4);
    expect(deltas()[0].removes.chests).toEqual(['chest_1']);
  });

  it('hexes never emit removes (a wire hex-remove means back-to-neutral) but re-upsert on return', () => {
    const { h, player, conn, view, sent, pump, deltas } = setup();
    h.runStart(conn);
    h.tick(1); // claim 0,0
    pump(2);
    expect(view.interest.hexes.size).toBe(1);
    h.teleport(player, 10_000, 10_000);
    player.updatedAt += 1; // make the mover visible so a frame ships at all
    sent.length = 0;
    pump(4);
    expect(deltas()[0].removes.hexes).toBeUndefined();
    expect(view.interest.hexes.size).toBe(0); // forgotten, not removed
    h.teleport(player, 0, 0);
    player.updatedAt += 1;
    sent.length = 0;
    pump(6);
    expect(deltas()[0].upserts.hexes?.map((x) => x.k)).toEqual(['0,0']);
  });
});

describe('outbox routing', () => {
  it('drains every tick, routed by audience, never to unbound connections', () => {
    const { h, player, view, sent, send } = setup();
    const now = h.clock.now();
    const ghost: OutboundConn = { connId: 'conn_ghost', playerId: null, interest: newInterest() };
    pushGameEvents(h.world, player.id, now, [{ k: 'notice', text: 'just you' }]);
    pushGameEvents(h.world, 'all', now, [{ k: 'notice', text: 'everyone' }]);
    pumpOutbound(h.world, [view, ghost], 3, now, send); // odd tick: outbox still drains
    const mine = sent.filter((s) => s.connId === view.connId && s.msg.op === OP.EVENTS);
    expect(mine).toHaveLength(2);
    expect(sent.filter((s) => s.connId === ghost.connId)).toHaveLength(0);
    // drained: a second pump delivers nothing
    sent.length = 0;
    pumpOutbound(h.world, [view, ghost], 5, now, send);
    expect(sent).toEqual([]);
  });
});

describe('computeDelta directly', () => {
  it('returns null (no frame) for a quiet window', () => {
    const { h, player, view } = setup();
    expect(computeDelta(h.world, player, view.interest, 2, h.clock.now())).not.toBeNull();
    expect(computeDelta(h.world, player, view.interest, 4, h.clock.now())).toBeNull();
  });
});
