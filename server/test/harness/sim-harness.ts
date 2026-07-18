// test/harness/sim-harness.ts — the fast inner loop: a real World + ManualClock
// driven through the real sim/loop, with every intent applied through the real
// applyCommand reducer. NO network, NO real clock — a unit test is deterministic
// and completes in microseconds. Ported from SideQuestAppV2 test/harness/
// sim-harness.ts (Cairn spawn/balance surface dropped; YAS join/gps sugar added).

import type { LatLng, Player, Vec2, World } from '../../shared/entities.js';
import type { ClientMsg, ServerMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import { TICK_HZ } from '../../shared/constants.js';
import { unproject } from '../../shared/geo.js';
import { seededRng } from '../../shared/rng.js';
import { createLoop, type Loop } from '../../sim/loop.js';
import { createWorld, deserialize, serialize } from '../../sim/world.js';
import { applyCommand, type CommandCtx, type Conn } from '../../sim/commands.js';
import { drainOutbox, type OutEvent } from '../../sim/systems/outbox.js';
import { ManualClock } from './manual-clock.js';

export const DEFAULT_ORIGIN: LatLng = { lat: 40.2338, lng: -111.6585 };

export interface SimHarnessOpts {
  seed: string;
  origin?: LatLng;
  /** Injected boot time; defaults to 0 so serialize() is byte-stable across runs. */
  now?: number;
  tickHz?: number;
}

export interface JoinedPlayer {
  player: Player;
  conn: Conn;
  frames: ServerMsg[];
}

export class SimHarness {
  readonly world: World;
  readonly clock: ManualClock;
  private readonly loop: Loop;
  private readonly tickHz: number;
  private readonly tickMs: number;
  private idSeq = 0;
  private cmdSeq = 0;

  private constructor(world: World, clock: ManualClock, tickHz: number) {
    this.world = world;
    this.clock = clock;
    this.tickHz = tickHz;
    this.tickMs = 1000 / tickHz;
    this.loop = createLoop({ world, tickHz, clock });
  }

  /** Build a virgin world for `seed`. Same opts + same script ⇒ byte-identical serialize(). */
  static create(opts: SimHarnessOpts): SimHarness {
    const world = createWorld(opts.seed, opts.origin ?? DEFAULT_ORIGIN, opts.now ?? 0);
    return new SimHarness(world, new ManualClock(opts.now ?? 0), opts.tickHz ?? TICK_HZ);
  }

  /** Rehydrate a world from a serialize() blob — the persistence round-trip path. */
  static fromSave(blob: string, opts: { tickHz?: number } = {}): SimHarness {
    const world = deserialize(blob);
    return new SimHarness(world, new ManualClock(world.createdAt), opts.tickHz ?? TICK_HZ);
  }

  /** Advance `n` fixed ticks deterministically (moves the clock, then forces each step). */
  tick(n = 1): this {
    for (let i = 0; i < n; i++) {
      this.clock.advance(this.tickMs);
      this.loop.step();
    }
    return this;
  }

  /** Advance wall time and let the loop's accumulator run the due ticks (burst-capped). */
  advance(ms: number): this {
    this.clock.advance(ms);
    this.loop.pump();
    return this;
  }

  /** Mint a deterministic in-process connection record (no socket). */
  newConn(): Conn {
    return { connId: `conn_${++this.idSeq}`, playerId: null, sessionToken: '' };
  }

  /** Run one intent through the real reducer with a fabricated deterministic ctx. */
  apply(cmd: ClientMsg, conn: Conn): ServerMsg[] {
    const seq = ++this.cmdSeq;
    const ctx: CommandCtx = {
      now: this.clock.now(),
      rng: seededRng(this.world.seed, conn.connId, this.world.tick, seq),
      conn,
      tickHz: this.tickHz,
      genId: (kind) => `${kind}_${++this.idSeq}`,
    };
    return applyCommand(this.world, cmd, ctx);
  }

  /** JOIN a fresh (or returning) player on its own connection. */
  join(gamertag: string, characterId = 'knight'): JoinedPlayer {
    const conn = this.newConn();
    const frames = this.apply(
      { op: OP.JOIN, t: this.clock.now(), protocolVersion: 1, gamertag, characterId },
      conn,
    );
    const player = conn.playerId ? this.world.players.get(conn.playerId) : undefined;
    if (!player) throw new Error(`SimHarness.join: JOIN did not bind a player (${gamertag})`);
    return { player, conn, frames };
  }

  /** Send a GPS fix at world-metre coords (unprojected through the world origin). */
  gpsAt(conn: Conn, v: Vec2, opts: { accuracy?: number; speedKmh?: number; steps?: number } = {}): ServerMsg[] {
    const ll = unproject(this.world.origin, v);
    return this.apply(
      {
        op: OP.GPS,
        t: this.clock.now(),
        lat: ll.lat,
        lng: ll.lng,
        accuracy: opts.accuracy ?? 5,
        ...(opts.speedKmh !== undefined ? { speedKmh: opts.speedKmh } : {}),
        ...(opts.steps !== undefined ? { steps: opts.steps } : {}),
      },
      conn,
    );
  }

  /** Test shortcut: place a pawn directly (bypasses the GPS guards on purpose). */
  teleport(player: Player, x: number, y: number): void {
    player.pos.x = x;
    player.pos.y = y;
    player.moveTarget = null;
  }

  runStart(conn: Conn): ServerMsg[] {
    return this.apply({ op: OP.RUN_START, t: this.clock.now() }, conn);
  }

  runEnd(conn: Conn): ServerMsg[] {
    return this.apply({ op: OP.RUN_END, t: this.clock.now() }, conn);
  }

  /** Take everything queued sim→gateway (audience-tagged frames). */
  drain(): OutEvent[] {
    return drainOutbox(this.world);
  }

  /** Deterministic JSON of the persisted world (byte-identical for identical histories). */
  serialize(): string {
    return serialize(this.world);
  }
}
