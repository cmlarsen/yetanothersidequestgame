// net/outbound.ts — the two-lane outbound pump (DESIGN §two-lane outbound).
// Lane 1: audience-tagged outbox events drain EVERY tick (combat/claim/notice beats
// reach the whole audience immediately). Lane 2: positional DELTAs broadcast at
// 5 Hz (tick % BROADCAST_EVERY_TICKS), per-connection interest window with change
// fingerprints — an unchanged entity never re-rides the wire, and an all-quiet
// window sends NO frame at all. Removes are emitted for entities leaving the
// window (except hexes — a wire hex-remove means "back to neutral", unused in v1).
//
// This lives at the net edge (per-connection, socket-facing) but reads a clock only
// via the injected `now` and touches no socket itself — the gateway supplies `send`.
// Ported from SideQuestAppV2 server/net/outbound.ts (players/monsters/breaches →
// the YAS lanes; FRONT_UPDATE fan-out added).

import type { Chest, GoldDrop, HexState, Mob, Player, Tower, World } from '../shared/entities.js';
import type {
  ChestWire,
  DeltaMsg,
  FrontUpdateMsg,
  GoldDropWire,
  HexWire,
  MobWire,
  PlayerWire,
  ServerMsg,
  TowerWire,
} from '../shared/protocol.js';
import { OP, OWNER_GLOOM, OWNER_PLAYERS } from '../shared/protocol.js';
import { BROADCAST_EVERY_TICKS, RELEVANCE_M } from '../shared/constants.js';
import { within } from '../shared/geo.js';
import { hexCenter, parseHexKey } from '../shared/hexgrid.js';
import { towerDurabilityMax } from '../shared/tuning.js';
import { drainOutbox } from '../sim/systems/outbox.js';
import { frontPcts, frontView } from '../sim/systems/fronts.js';

/** Per-connection interest memory: id → last-sent change fingerprint per lane. */
export interface Interest {
  /** playerId → the updatedAt we last shipped. */
  players: Map<string, number>;
  /** hexKey → the lastChangedAt we last shipped. */
  hexes: Map<string, number>;
  /** frontId → "pctPlayer:pctGloom" pair we last shipped. */
  fronts: Map<string, string>;
  /** mobId → rounded pos+hp fingerprint. */
  mobs: Map<string, string>;
  /** chestId → presence fingerprint (a chest only ever spawns then opens). */
  chests: Map<string, string>;
  /** towerId → durability/level fingerprint. */
  towers: Map<string, string>;
  /** goldDropId → amount fingerprint (own drops only). */
  goldDrops: Map<string, string>;
}

/** Fresh interest state for a new connection. */
export function newInterest(): Interest {
  return {
    players: new Map(),
    hexes: new Map(),
    fronts: new Map(),
    mobs: new Map(),
    chests: new Map(),
    towers: new Map(),
    goldDrops: new Map(),
  };
}

/** The gateway connection as the pump sees it (tests fabricate these directly). */
export interface OutboundConn {
  connId: string;
  playerId: string | null;
  interest: Interest;
}

export type SendFn = (connId: string, msg: ServerMsg) => void;

// ---------------------------------------------------------------------------
// Wire projections — mirrors of buildSnapshot's per-entity views in sim/world.ts
// (kept in lockstep; the shared/protocol wire interfaces pin the shapes).
// ---------------------------------------------------------------------------

function playerWire(p: Player): PlayerWire {
  return {
    id: p.id,
    gamertag: p.gamertag,
    characterId: p.characterId,
    x: p.pos.x,
    y: p.pos.y,
    hp: p.hp,
    maxHp: p.maxHp,
    level: p.level,
    state: p.lifeState,
    ...(p.partyId !== null ? { partyId: p.partyId } : {}),
  };
}

function hexWire(key: string, hs: HexState): HexWire {
  return {
    k: key,
    o: hs.owner === 'players' ? OWNER_PLAYERS : OWNER_GLOOM,
    f: hs.frontId,
    ...(hs.contestedMobId ? { c: hs.contestedMobId } : {}),
    ...(hs.towerId !== undefined ? { tw: hs.towerId } : {}),
  };
}

function mobWire(m: Mob): MobWire {
  return {
    id: m.id,
    sp: m.speciesId,
    lv: m.level,
    hp: m.hp,
    maxHp: m.maxHp,
    x: m.pos.x,
    y: m.pos.y,
    ...(m.isTyrant ? { ty: true } : {}),
  };
}

function chestWire(c: Chest): ChestWire {
  return { id: c.id, k: c.hexKey, x: c.pos.x, y: c.pos.y };
}

function towerWire(t: Tower): TowerWire {
  return {
    id: t.id,
    type: t.type,
    own: t.ownerId,
    k: t.hexKey,
    lvl: t.level,
    dur: Math.round(t.durability),
    maxDur: towerDurabilityMax(t.level),
    prio: t.targetPriority,
    rubble: t.isRubble,
  };
}

function goldDropWire(g: GoldDrop): GoldDropWire {
  return { id: g.id, x: g.pos.x, y: g.pos.y, gold: g.gold, expiresAt: g.expiresAt };
}

// ---------------------------------------------------------------------------
// Fingerprints — a cheap "did the client's view of this entity change" hash.
// ---------------------------------------------------------------------------

function mobFingerprint(m: Mob): string {
  return `${Math.round(m.pos.x)}:${Math.round(m.pos.y)}:${Math.round(m.hp)}`;
}

function towerFingerprint(t: Tower): string {
  return `${Math.round(t.durability)}:${t.level}:${t.targetPriority}:${t.isRubble ? 1 : 0}`;
}

// ---------------------------------------------------------------------------
// The 5 Hz lane.
// ---------------------------------------------------------------------------

/**
 * One generic interest lane: upsert what changed in-window, remove what left it,
 * mutate the fingerprint memory to match what was shipped.
 */
function lane<E, W, FP extends string | number>(
  entities: Iterable<E>,
  memory: Map<string, FP>,
  idOf: (e: E) => string,
  inWindow: (e: E) => boolean,
  fingerprint: (e: E) => FP,
  wire: (e: E) => W,
  opts: { emitRemoves: boolean },
): { upserts: W[]; removes: string[] } {
  const upserts: Array<{ id: string; w: W }> = [];
  const inRange = new Set<string>();
  for (const e of entities) {
    if (!inWindow(e)) continue;
    const id = idOf(e);
    inRange.add(id);
    const fp = fingerprint(e);
    if (memory.get(id) !== fp) {
      memory.set(id, fp);
      upserts.push({ id, w: wire(e) });
    }
  }
  const removes: string[] = [];
  for (const id of memory.keys()) {
    if (inRange.has(id)) continue;
    memory.delete(id);
    if (opts.emitRemoves) removes.push(id);
  }
  upserts.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return { upserts: upserts.map((u) => u.w), removes };
}

/**
 * computeDelta — the DELTA for `viewer` this broadcast tick, mutating `interest`
 * to reflect what was sent. Returns null when nothing changed and nothing left
 * range (skip the frame entirely — no empty frames on the wire).
 */
export function computeDelta(
  world: World,
  viewer: Player,
  interest: Interest,
  tick: number,
  now: number,
): DeltaMsg | null {
  const center = viewer.pos;
  const win = (pos: { x: number; y: number }): boolean => within(pos, center, RELEVANCE_M);
  const hexWin = (key: string): boolean => {
    const qr = parseHexKey(key);
    return qr !== null && win(hexCenter(qr.q, qr.r));
  };

  // Offline players are ghosts, not map entities — dropping out of the window here
  // is what turns a disconnect into a remove for everyone watching.
  const players = lane(
    world.players.values(),
    interest.players,
    (p) => p.id,
    (p) => p.connId !== null && win(p.pos),
    (p) => p.updatedAt,
    playerWire,
    { emitRemoves: true },
  );

  // Hexes never emit removes: the wire contract reads a hex-remove as
  // back-to-neutral (unused in v1 — no decay). Leaving the window just clears the
  // fingerprint so the hex re-upserts if the viewer returns.
  const hexes = lane(
    world.hexes.entries(),
    interest.hexes,
    ([k]) => k,
    ([k]) => hexWin(k),
    ([, hs]) => hs.lastChangedAt,
    ([k, hs]) => hexWire(k, hs),
    { emitRemoves: false },
  );

  const mobs = lane(
    world.mobs.values(),
    interest.mobs,
    (m) => m.id,
    (m) => win(m.pos),
    mobFingerprint,
    mobWire,
    { emitRemoves: true },
  );

  // An opened chest leaves the window (state fingerprint) → remove, so the client
  // clears the map marker the moment anyone loots it.
  const chests = lane(
    world.chests.values(),
    interest.chests,
    (c) => c.id,
    (c) => c.openedBy === undefined && win(c.pos),
    () => 'live',
    chestWire,
    { emitRemoves: true },
  );

  const towers = lane(
    world.towers.values(),
    interest.towers,
    (t) => t.id,
    (t) => hexWin(t.hexKey),
    towerFingerprint,
    towerWire,
    { emitRemoves: true },
  );

  // Your own drops ride regardless of distance (mirrors buildSnapshot): the death
  // screen's "recover your gold" marker must survive a respawn across the map.
  const goldDrops = lane(
    world.goldDrops.values(),
    interest.goldDrops,
    (g) => g.id,
    (g) => g.ownerId === viewer.id,
    (g) => `${g.gold}`,
    goldDropWire,
    { emitRemoves: true },
  );

  const lanes = [players, hexes, mobs, chests, towers, goldDrops];
  if (lanes.every((l) => l.upserts.length === 0 && l.removes.length === 0)) return null;

  const upserts: DeltaMsg['upserts'] = {};
  if (players.upserts.length) upserts.players = players.upserts;
  if (mobs.upserts.length) upserts.mobs = mobs.upserts;
  if (hexes.upserts.length) upserts.hexes = hexes.upserts;
  if (chests.upserts.length) upserts.chests = chests.upserts;
  if (towers.upserts.length) upserts.towers = towers.upserts;
  if (goldDrops.upserts.length) upserts.goldDrops = goldDrops.upserts;
  const removes: DeltaMsg['removes'] = {};
  if (players.removes.length) removes.players = players.removes;
  if (mobs.removes.length) removes.mobs = mobs.removes;
  if (chests.removes.length) removes.chests = chests.removes;
  if (towers.removes.length) removes.towers = towers.removes;
  if (goldDrops.removes.length) removes.goldDrops = goldDrops.removes;

  return { op: OP.DELTA, t: now, tick, upserts, removes };
}

/**
 * computeFrontUpdates — FRONT_UPDATE frames for every touched front whose
 * tug-of-war pct pair moved since this connection last saw it. Fronts have no
 * position, so no window and no removes — just the pair fingerprint.
 */
export function computeFrontUpdates(world: World, interest: Interest, now: number): FrontUpdateMsg[] {
  const out: FrontUpdateMsg[] = [];
  for (const id of [...world.fronts.keys()].sort()) {
    const { pctPlayer, pctGloom } = frontPcts(world, id);
    const fp = `${pctPlayer}:${pctGloom}`;
    if (interest.fronts.get(id) === fp) continue;
    interest.fronts.set(id, fp);
    out.push({ op: OP.FRONT_UPDATE, t: now, front: frontView(world, id) });
  }
  return out;
}

/**
 * pumpOutbound — the per-tick outbound pass the gateway (and tests) drive:
 * drain + route the outbox to bound connections every tick, then on broadcast
 * ticks emit per-connection FRONT_UPDATEs and the interest-windowed DELTA.
 */
export function pumpOutbound(
  world: World,
  conns: Iterable<OutboundConn>,
  tick: number,
  now: number,
  send: SendFn,
): void {
  const list = [...conns];

  for (const { to, msg } of drainOutbox(world)) {
    for (const conn of list) {
      if (conn.playerId === null) continue;
      if (to === 'all' || to === conn.playerId) send(conn.connId, msg);
    }
  }

  if (tick % BROADCAST_EVERY_TICKS !== 0) return;
  for (const conn of list) {
    if (conn.playerId === null) continue;
    const viewer = world.players.get(conn.playerId);
    if (!viewer) continue;
    for (const fu of computeFrontUpdates(world, conn.interest, now)) send(conn.connId, fu);
    const delta = computeDelta(world, viewer, conn.interest, tick, now);
    if (delta) send(conn.connId, delta);
  }
}
