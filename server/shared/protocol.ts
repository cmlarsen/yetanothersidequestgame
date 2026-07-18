// shared/protocol.ts — THE wire contract (JSON codec, zod source of truth).
// I/O-free, deterministic. The GDScript mirror (game/src/net/server_protocol.gd) is
// generated from THIS file by tools/protocol-gen. Wire-discipline rules carried from
// SideQuestAppV2 shared/protocol.ts: numeric ops are frozen forever, retired numbers
// stay reserved, new data rides optional fields. What V2 declared but never checked —
// protocolVersion — is ENFORCED here: JOIN/RESUME carry it; mismatch → ERR
// VERSION_MISMATCH and close.
//
// Envelope: client {op, t, seq?} · server {op, t}. `t` is sender-time ms; `seq` is an
// optional monotonic per-socket sequence.

import { z } from 'zod';
import { GEAR_SLOTS } from './catalog.js';
import type { GearSlot } from './catalog.js';
import type { LatLng, TargetPriority } from './entities.js';

/** Bumped whenever the wire shape changes incompatibly. Enforced at the gateway. */
export const PROTOCOL_VERSION = 1;

/** The single wire vocabulary. Numeric values ARE the contract: client 1–39,
 * server 100–139, never reuse a number. */
export enum OP {
  // ---- client → server ----
  JOIN = 1,
  RESUME = 2,
  GPS = 3,
  ATTACK = 4,
  USE_SLOT = 5,
  FLEE = 6,
  EQUIP = 7, // hotbar slot ← inventory instance
  EQUIP_GEAR = 8, // paper-doll slot ← inventory instance
  BUY = 9,
  SELL = 10,
  TOWER_BUILD = 11,
  TOWER_REPAIR = 12,
  TOWER_UPGRADE = 13,
  TOWER_SALVAGE = 14,
  TOWER_TARGET = 15,
  TOWER_REPAIR_ALL = 16,
  MINION_SEND = 17,
  MINION_COLLECT = 18,
  MINION_HIRE = 19,
  MINION_HEAL = 20,
  QUEST_CLAIM = 21,
  CHEST_OPEN = 22,
  PARTY_CREATE = 23,
  PARTY_JOIN = 24,
  PARTY_LEAVE = 25,
  RUN_START = 26,
  RUN_END = 27,
  RESPAWN = 28,
  REVIVE = 29,
  REQUEST_SNAPSHOT = 30,
  PONG = 31,

  // ---- server → client ----
  HELLO = 100,
  SNAPSHOT = 101,
  DELTA = 102,
  EVENTS = 103,
  ERR = 104,
  PING = 105,
  LOOT_RESULT = 106,
  INVENTORY_UPDATE = 107,
  FRONT_UPDATE = 108,
  RUN_SUMMARY = 109,
  DEATH = 110,
  LEVEL_UP = 111,
  PARTY_UPDATE = 112,
  SHOP_RESULT = 113,
  MINION_REPORT = 114,
}

/** Error codes on the ERR frame. Per-action errors never tear the socket —
 * except VERSION_MISMATCH, which closes after the frame. */
export const ERR_CODES = [
  'VERSION_MISMATCH',
  'SESSION_UNKNOWN',
  'BAD_REQUEST',
  'OUT_OF_RANGE',
  'ON_COOLDOWN',
  'INSUFFICIENT_GOLD',
  'INSUFFICIENT_MATERIALS',
  'CAP_REACHED',
  'NOT_FOUND',
  'ILLEGAL_STATE',
] as const;
export type ErrCode = (typeof ERR_CODES)[number];

// ---------------------------------------------------------------------------
// Client → server: one zod schema per message; the discriminated union is the codec.
// Schemas strip unknown keys (forward-compatible: newer clients may send extra
// optional fields).
// ---------------------------------------------------------------------------

const t = z.number();
const seq = z.number().int().nonnegative().optional();
const id = z.string().min(1);
const clientBase = { t, seq };

const hotbarSlot = z.number().int().min(0).max(4);
const gearSlot = z.enum(GEAR_SLOTS);
const towerType = z.enum(['bonk_turret', 'chill_bell', 'bastion_post']);
const jobId = z.enum(['gather_lumber', 'scout_front', 'scavenge']);
const targetPriority = z.enum(['nearest', 'strongest', 'guard_home']);

export const JoinSchema = z.object({
  op: z.literal(OP.JOIN),
  ...clientBase,
  protocolVersion: z.number().int(),
  gamertag: z.string().min(1).max(24),
  characterId: id,
});
export const ResumeSchema = z.object({
  op: z.literal(OP.RESUME),
  ...clientBase,
  protocolVersion: z.number().int(),
  sessionToken: id,
});
export const GpsSchema = z.object({
  op: z.literal(OP.GPS),
  ...clientBase,
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracy: z.number().nonnegative(),
  heading: z.number().optional(),
  speedKmh: z.number().nonnegative().optional(),
  /** Client pedometer total for today (§14) — rides the GPS stream, no extra op. */
  steps: z.number().int().nonnegative().optional(),
});
export const AttackSchema = z.object({
  op: z.literal(OP.ATTACK),
  ...clientBase,
  /** Named mob, or nearest engaged/in-range mob when omitted (big ATTACK button = slot-1 weapon). */
  mobId: id.optional(),
});
export const UseSlotSchema = z.object({
  op: z.literal(OP.USE_SLOT),
  ...clientBase,
  slot: hotbarSlot,
  mobId: id.optional(),
});
export const FleeSchema = z.object({ op: z.literal(OP.FLEE), ...clientBase });
export const EquipSchema = z.object({
  op: z.literal(OP.EQUIP),
  ...clientBase,
  slot: hotbarSlot,
  /** Inventory instance iid; null clears the slot. */
  iid: id.nullable(),
});
export const EquipGearSchema = z.object({
  op: z.literal(OP.EQUIP_GEAR),
  ...clientBase,
  gearSlot,
  iid: id.nullable(),
});
export const BuySchema = z.object({
  op: z.literal(OP.BUY),
  ...clientBase,
  itemId: id,
});
export const SellSchema = z.object({
  op: z.literal(OP.SELL),
  ...clientBase,
  iid: id,
});
export const TowerBuildSchema = z.object({
  op: z.literal(OP.TOWER_BUILD),
  ...clientBase,
  type: towerType,
  /** The hex to build on; server validates standing ≤ TOWER_PLACE_RADIUS_M on it. */
  hexKey: id,
});
export const TowerRepairSchema = z.object({
  op: z.literal(OP.TOWER_REPAIR),
  ...clientBase,
  towerId: id,
});
export const TowerUpgradeSchema = z.object({
  op: z.literal(OP.TOWER_UPGRADE),
  ...clientBase,
  towerId: id,
});
export const TowerSalvageSchema = z.object({
  op: z.literal(OP.TOWER_SALVAGE),
  ...clientBase,
  towerId: id,
});
export const TowerTargetSchema = z.object({
  op: z.literal(OP.TOWER_TARGET),
  ...clientBase,
  towerId: id,
  priority: targetPriority,
});
export const TowerRepairAllSchema = z.object({ op: z.literal(OP.TOWER_REPAIR_ALL), ...clientBase });
export const MinionSendSchema = z.object({
  op: z.literal(OP.MINION_SEND),
  ...clientBase,
  minionId: id,
  jobId,
  /** Scout the Front: which front to scout. */
  frontId: id.optional(),
});
export const MinionCollectSchema = z.object({
  op: z.literal(OP.MINION_COLLECT),
  ...clientBase,
  minionId: id,
});
export const MinionHireSchema = z.object({ op: z.literal(OP.MINION_HIRE), ...clientBase });
export const MinionHealSchema = z.object({
  op: z.literal(OP.MINION_HEAL),
  ...clientBase,
  minionId: id,
});
export const QuestClaimSchema = z.object({
  op: z.literal(OP.QUEST_CLAIM),
  ...clientBase,
  questId: id,
});
export const ChestOpenSchema = z.object({
  op: z.literal(OP.CHEST_OPEN),
  ...clientBase,
  chestId: id,
});
export const PartyCreateSchema = z.object({ op: z.literal(OP.PARTY_CREATE), ...clientBase });
export const PartyJoinSchema = z.object({
  op: z.literal(OP.PARTY_JOIN),
  ...clientBase,
  code: z.string().min(1).max(16),
});
export const PartyLeaveSchema = z.object({ op: z.literal(OP.PARTY_LEAVE), ...clientBase });
export const RunStartSchema = z.object({ op: z.literal(OP.RUN_START), ...clientBase });
export const RunEndSchema = z.object({ op: z.literal(OP.RUN_END), ...clientBase });
export const RespawnSchema = z.object({ op: z.literal(OP.RESPAWN), ...clientBase });
export const ReviveSchema = z.object({
  op: z.literal(OP.REVIVE),
  ...clientBase,
  playerId: id,
});
export const RequestSnapshotSchema = z.object({ op: z.literal(OP.REQUEST_SNAPSHOT), ...clientBase });
export const PongSchema = z.object({ op: z.literal(OP.PONG), ...clientBase });

export const ClientMsgSchema = z.discriminatedUnion('op', [
  JoinSchema,
  ResumeSchema,
  GpsSchema,
  AttackSchema,
  UseSlotSchema,
  FleeSchema,
  EquipSchema,
  EquipGearSchema,
  BuySchema,
  SellSchema,
  TowerBuildSchema,
  TowerRepairSchema,
  TowerUpgradeSchema,
  TowerSalvageSchema,
  TowerTargetSchema,
  TowerRepairAllSchema,
  MinionSendSchema,
  MinionCollectSchema,
  MinionHireSchema,
  MinionHealSchema,
  QuestClaimSchema,
  ChestOpenSchema,
  PartyCreateSchema,
  PartyJoinSchema,
  PartyLeaveSchema,
  RunStartSchema,
  RunEndSchema,
  RespawnSchema,
  ReviveSchema,
  RequestSnapshotSchema,
  PongSchema,
]);

export type ClientMsg = z.infer<typeof ClientMsgSchema>;
export type JoinMsg = z.infer<typeof JoinSchema>;
export type ResumeMsg = z.infer<typeof ResumeSchema>;
export type GpsMsg = z.infer<typeof GpsSchema>;
export type AttackMsg = z.infer<typeof AttackSchema>;
export type UseSlotMsg = z.infer<typeof UseSlotSchema>;

// ---------------------------------------------------------------------------
// Wire shapes (lean projections of shared/entities.ts — the client renders these).
// ---------------------------------------------------------------------------

/** Hex owner on the wire: 1 = players, 2 = gloom. Neutral hexes never ride the wire. */
export const OWNER_PLAYERS = 1;
export const OWNER_GLOOM = 2;
export type OwnerWire = typeof OWNER_PLAYERS | typeof OWNER_GLOOM;

/** {k, o, f}: hex key, owner, front id — plus contested mob / tower when present. */
export interface HexWire {
  k: string;
  o: OwnerWire;
  f: string;
  c?: string; // contested mob id
  tw?: string; // tower id
}

export interface FrontWire {
  id: string;
  name: string;
  pctPlayer: number;
  pctGloom: number;
}

export interface PlayerWire {
  id: string;
  gamertag: string;
  characterId: string;
  x: number;
  y: number;
  hp: number;
  maxHp: number;
  level: number;
  state: 'alive' | 'downed';
  partyId?: string;
}

/** The joining player's own richer view (inventory rides INVENTORY_UPDATE). */
export interface SelfWire extends PlayerWire {
  xp: number;
  xpNext: number;
  gold: number;
  materials: number;
  homeHex: string;
  stepsToday: number;
}

export interface MobWire {
  id: string;
  sp: string; // speciesId
  lv: number;
  hp: number;
  maxHp: number;
  x: number;
  y: number;
  ty?: boolean; // isTyrant
}

export interface ChestWire {
  id: string;
  k: string;
  x: number;
  y: number;
}

export interface TowerWire {
  id: string;
  type: string;
  own: string; // ownerId
  k: string;
  lvl: number;
  dur: number;
  maxDur: number;
  prio: TargetPriority;
  rubble: boolean;
}

export interface MinionWire {
  id: string;
  defId: string;
  name: string;
  state: string;
  job?: { jobId: string; endsAt: number; frontId?: string };
}

export interface GoldDropWire {
  id: string;
  x: number;
  y: number;
  gold: number;
  expiresAt: number;
}

export interface ItemInstanceWire {
  iid: string;
  itemId: string;
  isNew?: boolean;
  charges?: number;
}

export interface StatsWire {
  hp: number;
  maxHp: number;
  atk: number;
  def: number;
  spd: number;
  critPct: number;
}

export interface PartyMemberWire {
  id: string;
  gamertag: string;
  characterId: string;
  state: 'online' | 'inCombat' | 'offline';
  x?: number;
  y?: number;
  hp?: number;
  maxHp?: number;
  level: number;
}

export interface PartyWire {
  id: string;
  code: string;
  leaderId: string;
  members: PartyMemberWire[];
}

/** Per-tick combat/notice beats (EVENTS frames are per-audience). */
export type GameEvent =
  | { k: 'hit'; mobId: string; by: string; dmg: number; crit?: boolean; mult?: number; kb?: number }
  | { k: 'player_hit'; playerId: string; by: string; dmg: number }
  | { k: 'kill'; mobId: string; by: string; hexKey: string }
  | { k: 'claim'; hexKey: string; o: OwnerWire; frontId: string }
  | { k: 'contest'; hexKey: string; mobId: string }
  | { k: 'front_complete'; frontId: string; gold: number }
  | { k: 'area'; frontId: string; name: string; xp: number } // NEW AREA toast
  | { k: 'revive'; playerId: string; by: string }
  | { k: 'gold_pickup'; id: string; gold: number }
  | { k: 'xp'; amount: number; reason?: string }
  | { k: 'gold'; amount: number; reason?: string }
  | { k: 'notice'; text: string };

// ---------------------------------------------------------------------------
// Server → client. The server constructs these (no runtime validation needed);
// encode = JSON.stringify.
// ---------------------------------------------------------------------------

interface ServerBase<O extends OP> {
  op: O;
  t: number;
}

export interface HelloMsg extends ServerBase<OP.HELLO> {
  protocolVersion: number;
  playerId: string;
  sessionToken: string;
  seed: string;
  origin: LatLng;
  tickHz: number;
  hexAcrossM: number;
}
export interface SnapshotMsg extends ServerBase<OP.SNAPSHOT> {
  tick: number;
  self: SelfWire;
  players: PlayerWire[];
  hexes: HexWire[];
  fronts: FrontWire[];
  mobs: MobWire[];
  chests: ChestWire[];
  towers: TowerWire[];
  minions: MinionWire[];
  goldDrops: GoldDropWire[];
  party: PartyWire | null;
}
export interface DeltaMsg extends ServerBase<OP.DELTA> {
  tick: number;
  upserts: {
    players?: PlayerWire[];
    mobs?: MobWire[];
    hexes?: HexWire[];
    chests?: ChestWire[];
    towers?: TowerWire[];
    goldDrops?: GoldDropWire[];
  };
  /** kind → removed ids ('hexes' removals mean back-to-neutral; unused in v1 — no decay). */
  removes: Record<string, string[]>;
}
export interface EventsMsg extends ServerBase<OP.EVENTS> {
  events: GameEvent[];
}
export interface ErrMsg extends ServerBase<OP.ERR> {
  code: ErrCode;
  message: string;
  refOp?: number;
}
export interface PingMsg extends ServerBase<OP.PING> {
  tServer: number;
}
export interface LootItemWire {
  itemId: string;
  rarity: string;
}
export interface LootResultMsg extends ServerBase<OP.LOOT_RESULT> {
  /** chest id or mob id the loot came from. */
  sourceId: string;
  items: LootItemWire[];
  gold: number;
  xp: number;
}
export interface InventoryUpdateMsg extends ServerBase<OP.INVENTORY_UPDATE> {
  inventory: ItemInstanceWire[];
  hotbar: (string | null)[]; // iids
  equipment: Record<GearSlot, string | null>; // iids
  gold: number;
  materials: number;
  stats: StatsWire;
}
export interface FrontUpdateMsg extends ServerBase<OP.FRONT_UPDATE> {
  front: FrontWire;
  completed?: boolean;
}
export interface RunSummaryMsg extends ServerBase<OP.RUN_SUMMARY> {
  runId: string;
  durationSec: number;
  hexesClaimed: number;
  mobsDefeated: number;
  xp: number;
  gold: number;
  lootItemIds: string[];
  goldDropped: number;
  /** frontId → pctPlayer delta over the run. */
  frontDelta: Record<string, number>;
}
export interface DeathMsg extends ServerBase<OP.DEATH> {
  diedAt: number;
  reviveDeadline: number;
  goldDropped: number;
  hexesLost: string[];
  hexesKept: number;
}
export interface LevelUpMsg extends ServerBase<OP.LEVEL_UP> {
  level: number;
  atk: number;
  def: number;
  hp: number;
  /** Unlock ids at skill levels (e.g. 'pocket_blizzard', 'cape_slot'). */
  unlocks: string[];
}
export interface PartyUpdateMsg extends ServerBase<OP.PARTY_UPDATE> {
  party: PartyWire | null;
}
export interface ShopStockWire {
  itemId: string;
  price: number;
  dealPct?: number;
}
export interface ShopResultMsg extends ServerBase<OP.SHOP_RESULT> {
  gold: number;
  stock: ShopStockWire[];
}
export interface MinionReportMsg extends ServerBase<OP.MINION_REPORT> {
  minionId: string;
  jobId: string;
  materials: number;
  salvageItemId?: string;
  injured: boolean;
  quote: string;
  /** Rumor deep-link to the relevant front (§9). */
  rumorFrontId?: string;
}

export type ServerMsg =
  | HelloMsg
  | SnapshotMsg
  | DeltaMsg
  | EventsMsg
  | ErrMsg
  | PingMsg
  | LootResultMsg
  | InventoryUpdateMsg
  | FrontUpdateMsg
  | RunSummaryMsg
  | DeathMsg
  | LevelUpMsg
  | PartyUpdateMsg
  | ShopResultMsg
  | MinionReportMsg;

export type Msg = ClientMsg | ServerMsg;

// ---------------------------------------------------------------------------
// Codec (pure JSON; a binary codec later sits behind this interface).
// ---------------------------------------------------------------------------

/** Serialize a message to a text frame. Pure. */
export function encode(msg: Msg): string {
  return JSON.stringify(msg);
}

/** Parse + validate a client text frame → typed ClientMsg. Throws (SyntaxError /
 * ZodError) on malformed JSON, unknown op, or a bad payload — the gateway maps a
 * throw to one ERR BAD_REQUEST frame. */
export function decodeClient(str: string): ClientMsg {
  return ClientMsgSchema.parse(JSON.parse(str));
}
