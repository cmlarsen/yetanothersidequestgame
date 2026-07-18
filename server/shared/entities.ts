// shared/entities.ts — the server state model as TS interfaces (FIELDS ONLY, no logic),
// per server/DESIGN.md + docs/design/yas-v1/DATA-MODEL.md. I/O-free, deterministic.
// P/R convention carried from SideQuestAppV2 shared/entities.ts:
//   P = persisted (survives restart; only *touched* rows are written),
//   R = runtime-only (rebuilt from seed + persisted progress; never saved).

import type { CharacterId, MinionDefId, MobSpeciesId, TowerTypeId, GearSlot, JobId } from './catalog.js';

// ---- shared scalars ----

export interface Vec2 {
  x: number;
  y: number;
}
export interface LatLng {
  lat: number;
  lng: number;
}

/** §1 hex ownership. Neutral hexes are ABSENT from World.hexes — never stored. */
export type HexOwner = 'players' | 'gloom';

/** §8 tower target priority: NEAREST | STRONGEST | GUARD HOME HEX. */
export type TargetPriority = 'nearest' | 'strongest' | 'guard_home';

export type MinionState = 'idle' | 'on_job' | 'injured';
export type QuestState = 'active' | 'claimable' | 'done';
export type PlayerLifeState = 'alive' | 'downed';

// ---------------------------------------------------------------------------
// World — P (world_meta row) + entity maps. Single world for v1 (the geo-shard
// seam is kept by passing `world` everywhere, per DESIGN.md).
// ---------------------------------------------------------------------------

export interface World {
  seed: string; // P
  origin: LatLng; // P projection anchor (equirect local tangent)
  createdAt: number; // P
  tick: number; // P — persists so the RNG cursor can't save-scum
  schemaVersion: number; // P
  dailyResetAt: number; // P next §10 daily-quest reset (DAILY_RESET_UTC_H)
  /** §1 ownership map, "q,r" key → state. Absent = neutral. P (non-neutral rows only). */
  hexes: Map<string, HexState>;
  /** §1 static seed-derived front registry (id → Front). Geometry re-derives from seed;
   * only progress fields persist (see Front). */
  fronts: Map<string, Front>;
  players: Map<string, Player>; // P
  /** §3 mob field. R — never persisted; re-derives from seed + gloom territory. */
  mobs: Map<string, Mob>;
  chests: Map<string, Chest>; // P
  towers: Map<string, Tower>; // P
  /** §9 minions per-player (ownerId → roster, ≤3). P. */
  minions: Map<string, Minion[]>;
  parties: Map<string, Party>; // P
  /** §2/§5 dropped-gold pickups on the map. P (short-lived rows, 1 h expiry). */
  goldDrops: Map<string, GoldDrop>;
}

// ---------------------------------------------------------------------------
// §1 HexState — P (only non-neutral hexes are stored/persisted).
// ---------------------------------------------------------------------------

export interface HexState {
  owner: HexOwner; // P
  frontId: string; // P — the super-cell front this hex belongs to (derivable; cached)
  towerId?: string; // P
  /** §1 CONTESTED: a gloom hex a player engaged; winner's side owns it. */
  contestedMobId?: string; // P
  lastChangedAt: number; // P
}

// ---------------------------------------------------------------------------
// §1 Front — static seed-derived partition cell (8×8 hexes). Geometry (cell coords,
// name, member hexes) re-derives from seed; tug-of-war %s are computed on read.
// ---------------------------------------------------------------------------

export interface Front {
  id: string; // R (derived: stable per seed + cell)
  name: string; // R (seeded street-name list; placeholder until real map data)
  cellX: number; // R super-cell coords in hex-space
  cellY: number; // R
  sizeHexes: number; // R (FRONT_CELL_HEXES² = 64)
  /** §1 gloom-pressure accumulator (fractional hexes owed; advances capture on tick). */
  gloomAccum: number; // P
  /** §1 set on 100%-player completion; pressure rests until completedAt + FRONT_RESET_H. */
  completedAt?: number; // P
  /** §9 Scout the Front intel: predicted gloom push timing shown on Defense view. */
  scoutIntel?: { pushEta: number; scoutedAt: number }; // P
}

// ---------------------------------------------------------------------------
// §2 DATA-MODEL Player — P (table `player`), runtime fields marked R.
// ---------------------------------------------------------------------------

export interface ItemInstance {
  iid: string; // P instance id (inventory identity; catalog id may repeat)
  itemId: string; // P catalog id (shared/catalog.ts ITEMS)
  isNew: boolean; // P gold-dot unseen marker
  /** Consumables: charges remaining (initialised from the catalog effect.charges). */
  charges?: number; // P
}

export interface PlayerSettings {
  gpsMode: 'high' | 'saver'; // P §14
  stepTracking: boolean; // P §14
  speedPause: boolean; // P §14 auto-pause claiming above SPEED_PAUSE_KMH
  reducedMotion: boolean; // P §14
  /** §13 per-trigger notification toggles. */
  notif: { attack: boolean; chest: boolean; party: boolean; minion: boolean }; // P
}

export interface Player {
  id: string; // P
  gamertag: string; // P — untrusted name-only identity for the closed test (DESIGN.md)
  characterId: CharacterId; // P
  /** Bearer resume token (no auth in v1; harden before open TestFlight). */
  sessionToken: string | null; // P
  connId: string | null; // R bound connection (null = offline)

  pos: Vec2; // P world metres
  gpsAccuracy: number; // R metres, from the last accepted fix
  moveTarget: Vec2 | null; // R GPS ingestion target (fix = move target, never teleport)
  speedKmh: number; // R last reported speed (drives the §14 claim/combat pause)

  hp: number; // P
  maxHp: number; // P cached derived (base(level) + Σ gear)
  level: number; // P
  xp: number; // P into the current level
  gold: number; // P
  materials: number; // P 🪵

  /** §3 hotbar: 5 uniform slots holding inventory instance iids (null = empty). */
  hotbar: (string | null)[]; // P
  /** §7 paper doll: gear slot → equipped instance iid. */
  equipment: Record<GearSlot, string | null>; // P
  inventory: ItemInstance[]; // P
  /** §10 quest progress by quest id. */
  quests: Record<string, QuestProgress>; // P

  homeHex: string; // P "q,r" — respawn + guard-home anchor
  partyId: string | null; // P
  /** §2 the active run. R — a crashed server ends the run (counters are celebratory). */
  run: RunState | null;
  /** §5 death state while downed. R. */
  death: DeathState | null;
  /** §3 per-hotbar-slot cooldown stamps: injected-clock ms the slot is ready again. R. */
  slotReadyAt: number[]; // R length HOTBAR_SLOTS
  lifeState: PlayerLifeState; // R

  /** §14 pedometer: steps today (client-reported), keyed to the current daily window. */
  stepsToday: number; // P
  /** §1 fronts already visited (first-visit +10 XP fired once each). */
  areasSeen: string[]; // P
  settings: PlayerSettings; // P
  lastSeenAt: number; // P — away digest window (§8)
  updatedAt: number; // P dirty-tracking
}

export interface QuestProgress {
  questId: string; // P
  progress: number; // P
  state: QuestState; // P
  /** Dailies: when this instance resets (dawn-local approximation). */
  resetAt?: number; // P
}

// §2 run counters — reported in RUN_SUMMARY; drives the §5 contested-loss cap.
export interface RunState {
  runId: string; // R
  startedAt: number; // R
  goldAtStart: number; // R banked gold when the run began (§2 early-end drop rule)
  hexesClaimed: string[]; // R "q,r" keys claimed this run
  /** Hexes claimed-but-contested this run (§5 death loss, cap DEATH_CONTESTED_HEX_LOSS_CAP). */
  contestedClaimed: string[]; // R
  mobsDefeated: number; // R
  xpEarned: number; // R
  goldEarned: number; // R
  lootItemIds: string[]; // R catalog ids picked up this run
  /** frontId → pctPlayer at run start (run summary shows the delta). */
  frontPctStart: Record<string, number>; // R
}

// §5 death & revive window.
export interface DeathState {
  diedAt: number; // R
  at: Vec2; // R death location (gold drop + revive walk-to target)
  reviveDeadline: number; // R diedAt + REVIVE_COUNTDOWN_SEC
  goldDropId: string | null; // R the GoldDrop spawned by this death
}

// §2/§5 dropped gold — persists 1 h, recoverable within 10 m by its owner.
export interface GoldDrop {
  id: string; // P
  ownerId: string; // P
  pos: Vec2; // P
  hexKey: string; // P
  gold: number; // P
  droppedAt: number; // P
  expiresAt: number; // P droppedAt + DROPPED_GOLD_PERSIST_HOURS
}

// ---------------------------------------------------------------------------
// §3 Mob — R (never persisted; the spawn field re-derives from seed + gloom
// territory, V2 ambient-field pattern with lissajous roam).
// ---------------------------------------------------------------------------

export interface Mob {
  id: string; // R stable per (seed, spawn cell) so reconnects agree
  speciesId: MobSpeciesId; // R
  level: number; // R
  isTyrant: boolean; // R
  hp: number; // R
  maxHp: number; // R
  pos: Vec2; // R
  homePos: Vec2; // R roam anchor (lissajous around this)
  hexKey: string; // R the hex it currently paints/holds
  /** Player ids currently in this fight (drop-in co-op share kill credit). */
  engagedBy: string[]; // R
  /** Chill/slow effects: injected-clock ms the slow wears off. */
  slowedUntil: number; // R
  /** Next retaliation swing stamp. */
  swingReadyAt: number; // R
}

// ---------------------------------------------------------------------------
// §6 Chest — P (server-spawned on hexes; removed after opening).
// ---------------------------------------------------------------------------

export interface Chest {
  id: string; // P
  hexKey: string; // P
  pos: Vec2; // P
  spawnedAt: number; // P
  /** Set when opened (kept one save-cycle for idempotent re-sends, then culled). */
  openedBy?: string; // P
}

// ---------------------------------------------------------------------------
// §8 Tower — P.
// ---------------------------------------------------------------------------

export interface TowerLogEntry {
  at: number; // P
  event: string; // P away-digest line ("repelled 3 Gloomlings", "took heavy damage")
}

export interface Tower {
  id: string; // P
  ownerId: string; // P
  type: TowerTypeId; // P
  hexKey: string; // P (1 per hex)
  level: number; // P 1..TOWER_MAX_LEVEL
  durability: number; // P 0..towerDurabilityMax(level); 0 = rubble
  targetPriority: TargetPriority; // P
  isRubble: boolean; // P rebuild requires a physical visit
  builtAt: number; // P
  /** Away digest source (§8) — capped ring, newest last. */
  log: TowerLogEntry[]; // P
}

// ---------------------------------------------------------------------------
// §9 Minion — P (wall-clock jobs run with the app closed, so they must survive
// a server restart).
// ---------------------------------------------------------------------------

export interface MinionJob {
  jobId: JobId; // P
  /** Scout the Front: which front is being scouted. */
  frontId?: string; // P
  startedAt: number; // P
  endsAt: number; // P wall-clock completion
  riskPct: number; // P injury roll on completion (§9)
}

export interface Minion {
  id: string; // P
  ownerId: string; // P
  defId: MinionDefId; // P (a hired 3rd reuses a def, per catalog)
  name: string; // P
  state: MinionState; // P
  job: MinionJob | null; // P
  hiredAt?: number; // P set on the 200 g merchant hire
}

// ---------------------------------------------------------------------------
// §12 Party — P. Member runtime state (online/inCombat/offline, lastLoc) is
// computed from the members' Player records on read.
// ---------------------------------------------------------------------------

export interface Party {
  id: string; // P
  /** Join code, BONK-4242 style (seeded generator). */
  code: string; // P
  leaderId: string; // P
  memberIds: string[]; // P ≤ PARTY_MAX
  createdAt: number; // P
}
