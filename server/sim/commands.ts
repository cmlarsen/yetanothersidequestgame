// sim/commands.ts — the SINGLE mutation entry point. Every client intent flows
// through applyCommand(world, cmd, ctx) → ServerMsg[]. Pure aside from mutating
// `world`: no clock reads, no Math.random (time & ids arrive via ctx; randomness
// via ctx.rng). Illegal intent → one ERR frame, zero mutation. Reducer shape
// ported from SideQuestAppV2 server/sim/commands.ts; the switch becomes a handler
// REGISTRY so the combat/economy/tower/minion modules register their own ops
// without touching this file.

import type { Player, World } from '../shared/entities.js';
import type { ClientMsg, ErrCode, ServerMsg } from '../shared/protocol.js';
import { OP, PROTOCOL_VERSION } from '../shared/protocol.js';
import type { Rng } from '../shared/rng.js';
import { characterDef } from '../shared/catalog.js';
import type { CharacterId } from '../shared/catalog.js';
import {
  buildHello,
  buildInventoryUpdate,
  buildSnapshot,
  createPlayer,
} from './world.js';
import { clearMoveTarget, ingestGps } from './systems/movement.js';
import {
  endRun,
  isInCombat,
  respawnAtHome,
  revivePlayer,
  startRun,
} from './systems/territory.js';
import { resetRunQuests } from './systems/quests.js';
import { within } from '../shared/geo.js';
import { REVIVE_RADIUS_M } from '../shared/tuning.js';

/** The reducer's view of one connection. The gateway owns the socket; the sim only
 * sees this binding record (mutated by JOIN/RESUME). */
export interface Conn {
  connId: string;
  playerId: string | null;
  sessionToken: string;
}

/** Injected per-command context — the sim's window onto time, randomness, identity. */
export interface CommandCtx {
  /** Injected clock value (ms). The sim never reads a wall clock itself. */
  now: number;
  /** Seeded RNG for this command (caller forks per (seed, connId, tick, seq)). */
  rng: Rng;
  conn: Conn;
  /** From config; stamped into HELLO so the client learns the tick rate. */
  tickHz: number;
  /** Deterministic id/token minter: counter-based in tests, random at the live edge. */
  genId: (kind: string) => string;
}

export type CommandHandler<M extends ClientMsg = ClientMsg> = (
  world: World,
  cmd: M,
  ctx: CommandCtx,
) => ServerMsg[];

const handlers = new Map<number, CommandHandler>();

/** Plug a handler for an op. Combat/economy/tower/minion modules call this at
 * module load; re-registering an op replaces (last wins — keep it 1:1 in prod). */
export function registerHandler<O extends ClientMsg['op']>(
  op: O,
  handler: CommandHandler<Extract<ClientMsg, { op: O }>>,
): void {
  handlers.set(op, handler as CommandHandler);
}

export function err(now: number, code: ErrCode, message: string, refOp?: number): ServerMsg {
  return { op: OP.ERR, t: now, code, message, ...(refOp !== undefined ? { refOp } : {}) };
}

/** Resolve the player bound to this connection (null → caller emits SESSION_UNKNOWN). */
export function boundPlayer(world: World, ctx: CommandCtx): Player | null {
  if (!ctx.conn.playerId) return null;
  return world.players.get(ctx.conn.playerId) ?? null;
}

function noSession(now: number, refOp: number): ServerMsg[] {
  return [err(now, 'SESSION_UNKNOWN', 'no player bound to this connection', refOp)];
}

/**
 * applyCommand — validate + apply one intent, returning the S→C frames to send back
 * on the issuing connection (in order). Fan-out to other players rides the outbox.
 */
export function applyCommand(world: World, cmd: ClientMsg, ctx: CommandCtx): ServerMsg[] {
  const handler = handlers.get(cmd.op);
  if (!handler) return [err(ctx.now, 'BAD_REQUEST', `op ${cmd.op} not handled`, cmd.op)];
  return handler(world, cmd, ctx);
}

// ---------------------------------------------------------------------------
// Core handlers (world-core ops). Combat (ATTACK/USE_SLOT/FLEE), economy
// (BUY/SELL/EQUIP*/CHEST_OPEN/QUEST_CLAIM), towers, minions, and party ops are
// registered by their own modules.
// ---------------------------------------------------------------------------

registerHandler(OP.JOIN, (world, cmd, ctx) => {
  if (cmd.protocolVersion !== PROTOCOL_VERSION) {
    return [err(ctx.now, 'VERSION_MISMATCH', `server speaks protocol v${PROTOCOL_VERSION}`, cmd.op)];
  }
  const gamertag = cmd.gamertag.trim();
  if (!gamertag) return [err(ctx.now, 'BAD_REQUEST', 'JOIN requires a non-empty gamertag', cmd.op)];

  // Name-only identity for the closed test (DESIGN: untrusted; harden before open TestFlight).
  let player = [...world.players.values()].find((p) => p.gamertag === gamertag);
  if (!player) {
    const def = characterDef(cmd.characterId);
    if (!def) return [err(ctx.now, 'BAD_REQUEST', `unknown character '${cmd.characterId}'`, cmd.op)];
    if (def.unlockLevel > 1) {
      return [err(ctx.now, 'BAD_REQUEST', `character '${cmd.characterId}' is locked`, cmd.op)];
    }
    player = createPlayer(world, {
      id: ctx.genId('player'),
      gamertag,
      characterId: cmd.characterId as CharacterId,
      sessionToken: ctx.genId('token'),
      now: ctx.now,
      genId: ctx.genId,
    });
  } else {
    player.sessionToken = ctx.genId('token'); // fresh bearer token every JOIN
    clearMoveTarget(player); // reopening → the next fix snaps (no walk, no hex-trail)
    player.updatedAt = ctx.now;
  }
  bind(player, ctx);
  player.lastSeenAt = ctx.now;
  return [
    buildHello(world, player, ctx.now, ctx.tickHz),
    buildSnapshot(world, player, ctx.now),
    buildInventoryUpdate(player, ctx.now),
  ];
});

registerHandler(OP.RESUME, (world, cmd, ctx) => {
  if (cmd.protocolVersion !== PROTOCOL_VERSION) {
    return [err(ctx.now, 'VERSION_MISMATCH', `server speaks protocol v${PROTOCOL_VERSION}`, cmd.op)];
  }
  const player = [...world.players.values()].find(
    (p) => p.sessionToken !== null && p.sessionToken === cmd.sessionToken,
  );
  if (!player) return [err(ctx.now, 'SESSION_UNKNOWN', 'no player for that session token', cmd.op)];
  clearMoveTarget(player);
  bind(player, ctx);
  player.lastSeenAt = ctx.now;
  return [
    buildHello(world, player, ctx.now, ctx.tickHz),
    buildSnapshot(world, player, ctx.now),
    buildInventoryUpdate(player, ctx.now),
  ];
});

function bind(player: Player, ctx: CommandCtx): void {
  player.connId = ctx.conn.connId;
  ctx.conn.playerId = player.id;
  ctx.conn.sessionToken = player.sessionToken ?? '';
}

registerHandler(OP.GPS, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  // A fix is a MOVE TARGET (guards + speed/steps live in the movement system);
  // positions flow back over DELTA, so no reply frame. §14 speed-pause is enforced
  // where claiming happens (territory) off the speed recorded here.
  ingestGps(world, self, cmd, ctx.now);
  return [];
});

registerHandler(OP.REQUEST_SNAPSHOT, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  return [buildSnapshot(world, self, ctx.now), buildInventoryUpdate(self, ctx.now)];
});

// Liveness is the gateway's bookkeeping (lastPong stamps); the reducer just accepts it.
registerHandler(OP.PONG, () => []);

registerHandler(OP.RUN_START, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.lifeState !== 'alive') return [err(ctx.now, 'ILLEGAL_STATE', 'downed', cmd.op)];
  if (self.run) return [err(ctx.now, 'ILLEGAL_STATE', 'a run is already active', cmd.op)];
  startRun(self, ctx.genId('run'), ctx.now);
  resetRunQuests(self); // §10 territory quests are "in one run"
  return [];
});

registerHandler(OP.RUN_END, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (!self.run) return [err(ctx.now, 'ILLEGAL_STATE', 'no active run', cmd.op)];
  // §2: ending mid-combat is a retreat — run gold above the start-of-run bank drops
  // on your last hex (recoverable 1 h / 10 m). A clean END keeps everything.
  const early = isInCombat(world, self);
  const summary = endRun(world, self, ctx.now, { early, dropIdHint: ctx.genId('gd') });
  return summary ? [summary] : [];
});

registerHandler(OP.RESPAWN, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.lifeState !== 'downed') return [err(ctx.now, 'ILLEGAL_STATE', 'not downed', cmd.op)];
  respawnAtHome(world, self, ctx.now);
  return [buildSnapshot(world, self, ctx.now)];
});

registerHandler(OP.REVIVE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.lifeState !== 'alive') return [err(ctx.now, 'ILLEGAL_STATE', 'you are downed', cmd.op)];
  const target = world.players.get(cmd.playerId);
  if (!target) return [err(ctx.now, 'NOT_FOUND', 'no such player', cmd.op)];
  if (target.lifeState !== 'downed' || !target.death) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'player is not downed', cmd.op)];
  }
  if (self.partyId === null || self.partyId !== target.partyId) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'revive is party-only', cmd.op)];
  }
  if (ctx.now >= target.death.reviveDeadline) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'revive window expired', cmd.op)];
  }
  if (!within(self.pos, target.pos, REVIVE_RADIUS_M)) {
    return [err(ctx.now, 'OUT_OF_RANGE', 'walk to your ally to revive', cmd.op)];
  }
  revivePlayer(world, target, self, ctx.now);
  return [];
});
