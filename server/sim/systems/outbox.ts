// sim/systems/outbox.ts — the audience-tagged sim→gateway event queue. PURE
// bookkeeping (WeakMap keyed by World identity, never persisted). Systems enqueue
// already-built frames for specific players (or 'all'); the gateway drains + routes
// them every tick. Ported from SideQuestAppV2 server/sim/systems/outbox.ts (breach/
// dialogue helpers dropped; GameEvent batching added for the YAS EVENTS frame).

import type { World } from '../../shared/entities.js';
import type { GameEvent, ServerMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';

/** An outbound event: delivered to the connection bound to `to`, or every connection for 'all'. */
export interface OutEvent {
  to: string | 'all';
  msg: ServerMsg;
}

const outbox = new WeakMap<World, OutEvent[]>();

export function pushEvent(world: World, ev: OutEvent): void {
  let q = outbox.get(world);
  if (!q) {
    q = [];
    outbox.set(world, q);
  }
  q.push(ev);
}

/** Enqueue one already-built frame to each addressed player. */
export function emitTo(world: World, audience: readonly (string | 'all')[], msg: ServerMsg): void {
  for (const to of audience) pushEvent(world, { to, msg });
}

/** Frame + enqueue combat/claim/notice beats as one EVENTS frame for `to`. */
export function pushGameEvents(
  world: World,
  to: string | 'all',
  now: number,
  events: GameEvent[],
): void {
  if (events.length === 0) return;
  pushEvent(world, { to, msg: { op: OP.EVENTS, t: now, events } });
}

/** Take & clear all pending events (the gateway routes them; tests inspect them). */
export function drainOutbox(world: World): OutEvent[] {
  const q = outbox.get(world);
  if (!q || q.length === 0) return [];
  outbox.set(world, []);
  return q;
}
