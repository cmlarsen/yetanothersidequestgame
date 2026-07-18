// sim/world.ts — the authoritative in-memory World: pure construction, deterministic
// (de)serialization, the fixed-order tick, and the wire builders. I/O-free, no
// Date.now / Math.random — time is injected `now`, randomness flows through
// shared/rng seeded from (world.seed, namespace, world.tick). Serialize/tick shape
// ported from SideQuestAppV2 server/sim/world.ts, re-modelled onto the YAS entities.

import type {
  Chest,
  Front,
  GoldDrop,
  HexState,
  ItemInstance,
  LatLng,
  Minion,
  Party,
  Player,
  QuestProgress,
  Tower,
  World,
} from '../shared/entities.js';
import type {
  ChestWire,
  GoldDropWire,
  HelloMsg,
  HexWire,
  InventoryUpdateMsg,
  ItemInstanceWire,
  MinionWire,
  MobWire,
  PartyMemberWire,
  PartyWire,
  PlayerWire,
  SelfWire,
  SnapshotMsg,
  StatsWire,
  TowerWire,
} from '../shared/protocol.js';
import { OP, OWNER_GLOOM, OWNER_PLAYERS, PROTOCOL_VERSION } from '../shared/protocol.js';
import { GEAR_SLOTS, DEFAULT_HOTBAR, MINIONS, QUESTS, itemDef, questDef } from '../shared/catalog.js';
import type { CharacterId, GearSlot, MinionDefId, QuestId } from '../shared/catalog.js';
import {
  CRIT_BASE_PCT,
  HOTBAR_SLOTS,
  LEVEL_UP_ATK,
  LEVEL_UP_DEF,
  LEVEL_UP_HP,
  towerDurabilityMax,
  xpForLevel,
} from '../shared/tuning.js';
import { RELEVANCE_M } from '../shared/constants.js';
import { HEX_ACROSS_M, hexCenter, hexKeyAt, parseHexKey } from '../shared/hexgrid.js';
import { within } from '../shared/geo.js';
import { stepMovement } from './systems/movement.js';
import { stepTerritory } from './systems/territory.js';
import { stepGloom } from './systems/gloom.js';
import { ensureFront, frontIdAt, frontView, recountFronts } from './systems/fronts.js';

/** Bumped when the persisted world shape changes. */
export const SCHEMA_VERSION = 1;

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;

/** §10 "dawn local" approximation: dailies reset at a fixed UTC hour. 13:00 UTC ≈
 * 6–7 am US Mountain (the closed-test geography); main.ts overrides from env. */
export const DEFAULT_DAILY_RESET_UTC_H = 13;

// ---------------------------------------------------------------------------
// Player base stats (§7). GAME-RULES gives the per-level bumps; the level-1 bases
// are anchored to the paper-doll mock (LV 13: HP 184 (+52 gear) → base 132 = 12 +
// 10×12; ATK 42 (+18) → base 24 = 0 + 2×12; DEF 31 (+14) → base 17 = 5 + 1×12;
// SPD 12 (+2) → base 10, no level growth).
// ---------------------------------------------------------------------------
export const PLAYER_BASE_HP = 12;
export const PLAYER_BASE_ATK = 0;
export const PLAYER_BASE_DEF = 5;
export const PLAYER_BASE_SPD = 10;

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

/** Pure next-reset stamp: the first `utcH`:00 UTC strictly after `now`. */
export function nextDailyResetAt(now: number, utcH: number = DEFAULT_DAILY_RESET_UTC_H): number {
  const day = Math.floor(now / DAY_MS) * DAY_MS;
  const at = day + utcH * HOUR_MS;
  return at > now ? at : at + DAY_MS;
}

/**
 * createWorld — build a virgin world. Pure & deterministic: same (seed, origin,
 * createdAt) ⇒ byte-identical serialize(). `createdAt` defaults to 0 so tests get
 * determinism for free; main.ts passes the real boot time.
 */
export function createWorld(
  seed: string,
  origin: LatLng,
  createdAt = 0,
  opts: { dailyResetUtcH?: number } = {},
): World {
  return {
    seed,
    origin,
    createdAt,
    tick: 0,
    schemaVersion: SCHEMA_VERSION,
    dailyResetAt: nextDailyResetAt(createdAt, opts.dailyResetUtcH),
    hexes: new Map(),
    fronts: new Map(),
    players: new Map(),
    mobs: new Map(),
    chests: new Map(),
    towers: new Map(),
    minions: new Map(),
    parties: new Map(),
    goldDrops: new Map(),
  };
}

// ---------------------------------------------------------------------------
// Player factory (used by the JOIN handler). Deterministic given its inputs.
// ---------------------------------------------------------------------------

/** Expand one starter-hotbar catalog id into an owned instance (charges seeded
 * from the catalog effect). */
function mintItem(iid: string, itemId: string): ItemInstance {
  const def = itemDef(itemId);
  const inst: ItemInstance = { iid, itemId, isNew: false };
  if (def?.effect.charges !== undefined) inst.charges = def.effect.charges;
  return inst;
}

/**
 * createPlayer — mint a fresh level-1 player with the starter kit: the
 * DEFAULT_HOTBAR loadout as owned instances, empty paper doll, the two starter
 * minions (§9), and the board quests seeded (dailies keyed to the next reset).
 * homeHex stays '' until the first claimed hex anchors it (territory).
 */
export function createPlayer(
  world: World,
  args: {
    id: string;
    gamertag: string;
    characterId: CharacterId;
    sessionToken: string;
    now: number;
    genId: (kind: string) => string;
  },
): Player {
  const inventory: ItemInstance[] = [];
  const hotbar: (string | null)[] = [];
  for (const itemId of DEFAULT_HOTBAR) {
    if (itemId === null) {
      hotbar.push(null);
      continue;
    }
    const inst = mintItem(args.genId('item'), itemId);
    inventory.push(inst);
    hotbar.push(inst.iid);
  }
  const equipment = {} as Record<GearSlot, string | null>;
  for (const slot of GEAR_SLOTS) equipment[slot] = null;

  const quests: Record<string, QuestProgress> = {};
  for (const questId of Object.keys(QUESTS).sort() as QuestId[]) {
    const def = questDef(questId);
    if (!def || def.tab === 'story') continue; // story chains start at the NPC (§10)
    const qp: QuestProgress = { questId, progress: 0, state: 'active' };
    if (def.tab === 'daily') qp.resetAt = world.dailyResetAt;
    quests[questId] = qp;
  }

  const player: Player = {
    id: args.id,
    gamertag: args.gamertag,
    characterId: args.characterId,
    sessionToken: args.sessionToken,
    connId: null,
    pos: { x: 0, y: 0 },
    gpsAccuracy: 0,
    moveTarget: null,
    speedKmh: 0,
    hp: PLAYER_BASE_HP,
    maxHp: PLAYER_BASE_HP,
    level: 1,
    xp: 0,
    gold: 0,
    materials: 0,
    hotbar,
    equipment,
    inventory,
    quests,
    homeHex: '',
    partyId: null,
    run: null,
    death: null,
    slotReadyAt: new Array<number>(HOTBAR_SLOTS).fill(0),
    lifeState: 'alive',
    stepsToday: 0,
    areasSeen: [],
    settings: {
      gpsMode: 'high',
      stepTracking: true,
      speedPause: true,
      reducedMotion: false,
      notif: { attack: true, chest: true, party: true, minion: true },
    },
    lastSeenAt: args.now,
    updatedAt: args.now,
  };
  world.players.set(player.id, player);

  // §9 starter roster: Gruncle + Pip, idle.
  const roster: Minion[] = (Object.keys(MINIONS) as MinionDefId[]).map((defId) => ({
    id: args.genId('minion'),
    ownerId: player.id,
    defId,
    name: MINIONS[defId].name,
    state: 'idle',
    job: null,
  }));
  world.minions.set(player.id, roster);
  return player;
}

// ---------------------------------------------------------------------------
// Tick — clock-injected, deterministic, fixed system order. Combat/mob/chest/minion
// steppers are looked up from the ticker registry (their agents register at module
// load); an absent ticker is simply skipped.
// ---------------------------------------------------------------------------

export type TickerName = 'mobs' | 'combat' | 'chests' | 'minions';
export type Ticker = (world: World, dtMs: number, now: number) => void;

const tickers = new Map<TickerName, Ticker>();

/** Plug a system stepper into the fixed tick order. Re-registering replaces. */
export function registerTicker(name: TickerName, fn: Ticker): void {
  tickers.set(name, fn);
}

export function unregisterTicker(name: TickerName): void {
  tickers.delete(name);
}

/**
 * tickWorld(world, dtMs, now) — advance the sim one fixed step. Mutates `world` in
 * place and returns it. Order: movement → territory (claim-on-enter) → mob roam →
 * gloom pressure → combat → chests → minions → daily reset.
 */
export function tickWorld(world: World, dtMs: number, now: number): World {
  world.tick += 1;
  stepMovement(world, dtMs, now);
  stepTerritory(world, dtMs, now);
  tickers.get('mobs')?.(world, dtMs, now);
  stepGloom(world, dtMs, now);
  tickers.get('combat')?.(world, dtMs, now);
  tickers.get('chests')?.(world, dtMs, now);
  tickers.get('minions')?.(world, dtMs, now);
  stepDailyReset(world, now);
  return world;
}

/** §10 daily rollover: reset steps + daily-tab quest progress at the stamp. */
function stepDailyReset(world: World, now: number): void {
  if (now < world.dailyResetAt) return;
  while (world.dailyResetAt <= now) world.dailyResetAt += DAY_MS;
  for (const player of world.players.values()) {
    player.stepsToday = 0;
    for (const qp of Object.values(player.quests)) {
      if (questDef(qp.questId)?.tab !== 'daily') continue;
      qp.progress = 0;
      qp.state = 'active';
      qp.resetAt = world.dailyResetAt;
    }
    player.updatedAt = now;
  }
}

// ---------------------------------------------------------------------------
// Serialization — deterministic, byte-identical for the same world. Persisted
// fields only, every collection sorted, every object rebuilt in fixed key order.
// Runtime state is OMITTED: mobs (re-derive from seed + gloom), conn bindings,
// interest, move targets, run/death machines, cooldown stamps, contested combat
// markers (contestedMobId references a runtime mob).
// ---------------------------------------------------------------------------

function byId<T extends { id: string }>(a: T, b: T): number {
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

function persistedHex(key: string, hs: HexState): Record<string, unknown> {
  return {
    k: key,
    owner: hs.owner,
    frontId: hs.frontId,
    ...(hs.towerId !== undefined ? { towerId: hs.towerId } : {}),
    lastChangedAt: hs.lastChangedAt,
  };
}

function persistedFront(f: Front): Record<string, unknown> {
  return {
    id: f.id,
    gloomAccum: f.gloomAccum,
    ...(f.completedAt !== undefined ? { completedAt: f.completedAt } : {}),
    ...(f.scoutIntel !== undefined ? { scoutIntel: f.scoutIntel } : {}),
  };
}

function persistedItem(i: ItemInstance): Record<string, unknown> {
  return {
    iid: i.iid,
    itemId: i.itemId,
    isNew: i.isNew,
    ...(i.charges !== undefined ? { charges: i.charges } : {}),
  };
}

function persistedQuest(q: QuestProgress): Record<string, unknown> {
  return {
    questId: q.questId,
    progress: q.progress,
    state: q.state,
    ...(q.resetAt !== undefined ? { resetAt: q.resetAt } : {}),
  };
}

function persistedPlayer(p: Player): Record<string, unknown> {
  const quests: Record<string, unknown> = {};
  for (const k of Object.keys(p.quests).sort()) quests[k] = persistedQuest(p.quests[k]);
  const equipment: Record<string, string | null> = {};
  for (const slot of GEAR_SLOTS) equipment[slot] = p.equipment[slot];
  return {
    id: p.id,
    gamertag: p.gamertag,
    characterId: p.characterId,
    sessionToken: p.sessionToken,
    pos: { x: p.pos.x, y: p.pos.y },
    hp: p.hp,
    maxHp: p.maxHp,
    level: p.level,
    xp: p.xp,
    gold: p.gold,
    materials: p.materials,
    hotbar: [...p.hotbar],
    equipment,
    inventory: p.inventory.map(persistedItem),
    quests,
    homeHex: p.homeHex,
    partyId: p.partyId,
    stepsToday: p.stepsToday,
    areasSeen: [...p.areasSeen],
    settings: {
      gpsMode: p.settings.gpsMode,
      stepTracking: p.settings.stepTracking,
      speedPause: p.settings.speedPause,
      reducedMotion: p.settings.reducedMotion,
      notif: {
        attack: p.settings.notif.attack,
        chest: p.settings.notif.chest,
        party: p.settings.notif.party,
        minion: p.settings.notif.minion,
      },
    },
    lastSeenAt: p.lastSeenAt,
    updatedAt: p.updatedAt,
  };
}

function persistedChest(c: Chest): Record<string, unknown> {
  return {
    id: c.id,
    hexKey: c.hexKey,
    pos: { x: c.pos.x, y: c.pos.y },
    spawnedAt: c.spawnedAt,
    ...(c.openedBy !== undefined ? { openedBy: c.openedBy } : {}),
  };
}

function persistedTower(t: Tower): Record<string, unknown> {
  return {
    id: t.id,
    ownerId: t.ownerId,
    type: t.type,
    hexKey: t.hexKey,
    level: t.level,
    durability: t.durability,
    targetPriority: t.targetPriority,
    isRubble: t.isRubble,
    builtAt: t.builtAt,
    log: t.log.map((l) => ({ at: l.at, event: l.event })),
  };
}

function persistedMinion(m: Minion): Record<string, unknown> {
  return {
    id: m.id,
    ownerId: m.ownerId,
    defId: m.defId,
    name: m.name,
    state: m.state,
    job:
      m.job === null
        ? null
        : {
            jobId: m.job.jobId,
            ...(m.job.frontId !== undefined ? { frontId: m.job.frontId } : {}),
            startedAt: m.job.startedAt,
            endsAt: m.job.endsAt,
            riskPct: m.job.riskPct,
          },
    ...(m.hiredAt !== undefined ? { hiredAt: m.hiredAt } : {}),
  };
}

function persistedParty(p: Party): Record<string, unknown> {
  return {
    id: p.id,
    code: p.code,
    leaderId: p.leaderId,
    memberIds: [...p.memberIds],
    createdAt: p.createdAt,
  };
}

function persistedGoldDrop(g: GoldDrop): Record<string, unknown> {
  return {
    id: g.id,
    ownerId: g.ownerId,
    pos: { x: g.pos.x, y: g.pos.y },
    hexKey: g.hexKey,
    gold: g.gold,
    droppedAt: g.droppedAt,
    expiresAt: g.expiresAt,
  };
}

/** serialize(world) → deterministic JSON string. Same world ⇒ identical bytes. */
export function serialize(world: World): string {
  return JSON.stringify({
    seed: world.seed,
    origin: { lat: world.origin.lat, lng: world.origin.lng },
    createdAt: world.createdAt,
    tick: world.tick,
    schemaVersion: world.schemaVersion,
    dailyResetAt: world.dailyResetAt,
    hexes: [...world.hexes.entries()]
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([k, hs]) => persistedHex(k, hs)),
    fronts: [...world.fronts.values()].sort(byId).map(persistedFront),
    players: [...world.players.values()].sort(byId).map(persistedPlayer),
    chests: [...world.chests.values()].sort(byId).map(persistedChest),
    towers: [...world.towers.values()].sort(byId).map(persistedTower),
    minions: [...world.minions.entries()]
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .flatMap(([, roster]) => roster.map(persistedMinion)),
    parties: [...world.parties.values()].sort(byId).map(persistedParty),
    goldDrops: [...world.goldDrops.values()].sort(byId).map(persistedGoldDrop),
  });
}

interface SerializedWorldShape {
  seed: string;
  origin: LatLng;
  createdAt: number;
  tick: number;
  schemaVersion: number;
  dailyResetAt: number;
  hexes: Array<{ k: string } & Omit<HexState, 'contestedMobId'>>;
  fronts: Array<Pick<Front, 'id' | 'gloomAccum' | 'completedAt' | 'scoutIntel'>>;
  players: Array<Record<string, unknown>>;
  chests: Chest[];
  towers: Tower[];
  minions: Minion[];
  parties: Party[];
  goldDrops: GoldDrop[];
}

/** deserialize(json) → World. Rehydrates persisted state; runtime fields start at
 * their defaults (offline, alive, no run, no targets); front counters recount. */
export function deserialize(json: string): World {
  const s = JSON.parse(json) as SerializedWorldShape;
  const world = createWorld(s.seed, s.origin, s.createdAt);
  world.tick = s.tick ?? 0;
  world.schemaVersion = s.schemaVersion ?? SCHEMA_VERSION;
  world.dailyResetAt = s.dailyResetAt ?? world.dailyResetAt;
  for (const h of s.hexes ?? []) {
    world.hexes.set(h.k, {
      owner: h.owner,
      frontId: h.frontId,
      ...(h.towerId !== undefined ? { towerId: h.towerId } : {}),
      lastChangedAt: h.lastChangedAt,
    });
  }
  recountFronts(world); // materializes every touched front; progress overlays below
  for (const f of s.fronts ?? []) {
    const front = ensureFront(world, f.id);
    front.gloomAccum = f.gloomAccum ?? 0;
    if (f.completedAt !== undefined) front.completedAt = f.completedAt;
    if (f.scoutIntel !== undefined) front.scoutIntel = f.scoutIntel;
  }
  for (const raw of s.players ?? []) {
    const p = raw as unknown as Player;
    world.players.set(p.id, {
      ...p,
      connId: null,
      gpsAccuracy: 0,
      moveTarget: null,
      speedKmh: 0,
      run: null,
      death: null,
      slotReadyAt: new Array<number>(HOTBAR_SLOTS).fill(0),
      lifeState: 'alive',
    });
  }
  for (const c of s.chests ?? []) world.chests.set(c.id, c);
  for (const t of s.towers ?? []) world.towers.set(t.id, t);
  for (const m of s.minions ?? []) {
    const roster = world.minions.get(m.ownerId) ?? [];
    roster.push(m);
    world.minions.set(m.ownerId, roster);
  }
  for (const p of s.parties ?? []) world.parties.set(p.id, p);
  for (const g of s.goldDrops ?? []) world.goldDrops.set(g.id, g);
  return world;
}

// ---------------------------------------------------------------------------
// Derived stats (§7): base(level) + Σ equipped gear. maxHp is CACHED on the player
// (level-ups and gear swaps recompute); the rest derive on read.
// ---------------------------------------------------------------------------

export function playerStats(player: Player): StatsWire {
  let hp = PLAYER_BASE_HP + LEVEL_UP_HP * (player.level - 1);
  let atk = PLAYER_BASE_ATK + LEVEL_UP_ATK * (player.level - 1);
  let def = PLAYER_BASE_DEF + LEVEL_UP_DEF * (player.level - 1);
  let spd = PLAYER_BASE_SPD;
  let critPct = CRIT_BASE_PCT;
  for (const slot of GEAR_SLOTS) {
    const iid = player.equipment[slot];
    if (!iid) continue;
    const inst = player.inventory.find((i) => i.iid === iid);
    const stats = inst ? itemDef(inst.itemId)?.stats : undefined;
    if (!stats) continue;
    hp += stats.hp ?? 0;
    atk += stats.atk ?? 0;
    def += stats.def ?? 0;
    spd += stats.spd ?? 0;
    critPct += stats.critPct ?? 0;
  }
  return { hp: player.hp, maxHp: hp, atk, def, spd, critPct };
}

/** Recompute + cache maxHp after a gear change (clamping hp into the new max). */
export function refreshMaxHp(player: Player): void {
  const s = playerStats(player);
  player.maxHp = s.maxHp;
  if (player.hp > player.maxHp) player.hp = player.maxHp;
}

// ---------------------------------------------------------------------------
// Wire builders — pure READS (never mutate the world; snapshot must not change
// serialize() output). Interest window: RELEVANCE_M around the viewer.
// ---------------------------------------------------------------------------

export function buildHello(world: World, player: Player, now: number, tickHz: number): HelloMsg {
  return {
    op: OP.HELLO,
    t: now,
    protocolVersion: PROTOCOL_VERSION,
    playerId: player.id,
    sessionToken: player.sessionToken ?? '',
    seed: world.seed,
    origin: world.origin,
    tickHz,
    hexAcrossM: HEX_ACROSS_M,
  };
}

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

function selfWire(p: Player): SelfWire {
  return {
    ...playerWire(p),
    xp: p.xp,
    xpNext: xpForLevel(p.level),
    gold: p.gold,
    materials: p.materials,
    homeHex: p.homeHex,
    stepsToday: p.stepsToday,
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

function minionWire(m: Minion): MinionWire {
  return {
    id: m.id,
    defId: m.defId,
    name: m.name,
    state: m.state,
    ...(m.job !== null
      ? {
          job: {
            jobId: m.job.jobId,
            endsAt: m.job.endsAt,
            ...(m.job.frontId !== undefined ? { frontId: m.job.frontId } : {}),
          },
        }
      : {}),
  };
}

export function buildPartyWire(world: World, party: Party): PartyWire {
  const members: PartyMemberWire[] = [];
  for (const id of party.memberIds) {
    const p = world.players.get(id);
    if (!p) continue;
    const online = p.connId !== null;
    // 'inCombat' refinement belongs to the combat system; online/offline here.
    members.push({
      id: p.id,
      gamertag: p.gamertag,
      characterId: p.characterId,
      state: online ? 'online' : 'offline',
      ...(online ? { x: p.pos.x, y: p.pos.y, hp: p.hp, maxHp: p.maxHp } : {}),
      level: p.level,
    });
  }
  return { id: party.id, code: party.code, leaderId: party.leaderId, members };
}

/**
 * buildSnapshot — the op101 world view for one player: non-neutral hexes, mobs,
 * chests, towers in the RELEVANCE_M window; every touched front + the player's
 * current one; the player's own minions, gold drops, and party. Pure read;
 * collections sorted for wire determinism.
 */
export function buildSnapshot(world: World, player: Player, now: number): SnapshotMsg {
  const pos = player.pos;
  const hexes: HexWire[] = [];
  for (const [key, hs] of world.hexes) {
    const qr = parseHexKey(key);
    if (!qr) continue;
    if (!within(hexCenter(qr.q, qr.r), pos, RELEVANCE_M)) continue;
    hexes.push(hexWire(key, hs));
  }
  hexes.sort((a, b) => (a.k < b.k ? -1 : a.k > b.k ? 1 : 0));

  const frontIds = new Set<string>(world.fronts.keys());
  const here = hexKeyAt(pos.x, pos.y);
  const hereQr = parseHexKey(here);
  if (hereQr) frontIds.add(frontIdAt(hereQr.q, hereQr.r));
  const fronts = [...frontIds].sort().map((id) => frontView(world, id));

  const mobs: MobWire[] = [];
  for (const m of world.mobs.values()) {
    if (!within(m.pos, pos, RELEVANCE_M)) continue;
    mobs.push({
      id: m.id,
      sp: m.speciesId,
      lv: m.level,
      hp: m.hp,
      maxHp: m.maxHp,
      x: m.pos.x,
      y: m.pos.y,
      ...(m.isTyrant ? { ty: true } : {}),
    });
  }
  mobs.sort(byId);

  const chests: ChestWire[] = [];
  for (const c of world.chests.values()) {
    if (c.openedBy !== undefined) continue;
    if (!within(c.pos, pos, RELEVANCE_M)) continue;
    chests.push({ id: c.id, k: c.hexKey, x: c.pos.x, y: c.pos.y });
  }
  chests.sort(byId);

  const towers: TowerWire[] = [];
  for (const t of world.towers.values()) {
    const qr = parseHexKey(t.hexKey);
    if (!qr || !within(hexCenter(qr.q, qr.r), pos, RELEVANCE_M)) continue;
    towers.push(towerWire(t));
  }
  towers.sort(byId);

  const goldDrops: GoldDropWire[] = [];
  for (const g of world.goldDrops.values()) {
    if (g.ownerId !== player.id) continue; // your drops only — wherever they fell
    goldDrops.push({ id: g.id, x: g.pos.x, y: g.pos.y, gold: g.gold, expiresAt: g.expiresAt });
  }
  goldDrops.sort(byId);

  const players: PlayerWire[] = [playerWire(player)];
  for (const p of world.players.values()) {
    if (p.id === player.id || p.connId === null) continue;
    if (!within(p.pos, pos, RELEVANCE_M)) continue;
    players.push(playerWire(p));
  }
  players.sort(byId);

  const party = player.partyId !== null ? world.parties.get(player.partyId) : undefined;

  return {
    op: OP.SNAPSHOT,
    t: now,
    tick: world.tick,
    self: selfWire(player),
    players,
    hexes,
    fronts,
    mobs,
    chests,
    towers,
    minions: (world.minions.get(player.id) ?? []).map(minionWire),
    goldDrops,
    party: party ? buildPartyWire(world, party) : null,
  };
}

/** The op107 bag/doll/stats frame (rides the JOIN/RESUME burst + REQUEST_SNAPSHOT). */
export function buildInventoryUpdate(player: Player, now: number): InventoryUpdateMsg {
  const inventory: ItemInstanceWire[] = player.inventory.map((i) => ({
    iid: i.iid,
    itemId: i.itemId,
    ...(i.isNew ? { isNew: true } : {}),
    ...(i.charges !== undefined ? { charges: i.charges } : {}),
  }));
  return {
    op: OP.INVENTORY_UPDATE,
    t: now,
    inventory,
    hotbar: [...player.hotbar],
    equipment: { ...player.equipment },
    gold: player.gold,
    materials: player.materials,
    stats: playerStats(player),
  };
}
