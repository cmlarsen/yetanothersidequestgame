// shared/catalog.ts — static content tables. MUST mirror game/src/data/catalog.gd
// EXACTLY by id and stat value (the shell renders these; tools codegen will later
// enforce equality — until then test/unit/catalog.test.ts cross-checks). Display-only
// fields (emoji, effectLine, taglines, bios) are carried on purpose: the server
// snapshot serves them so content iteration is a server deploy, not a client build.
// Pure data + lookups: I/O-free, deterministic (lint:purity enforced).

// ---- vocabulary ----

/** Loot rarity ladder (§6). 'mystery' is a display-only pseudo-rarity (Mystery Grumble Box). */
export const RARITIES = ['common', 'rare', 'epic', 'legendary'] as const;
export type Rarity = (typeof RARITIES)[number];
export type ItemRarity = Rarity | 'mystery';

/** Hotbar/paper-doll slot vocabulary (DATA-MODEL Item.slotType; strings match the shell). */
export const SLOT_TYPES = [
  'weapon',
  'spell',
  'consumable',
  'helm',
  'chest',
  'boots',
  'cape',
  'off_hand',
] as const;
export type SlotType = (typeof SLOT_TYPES)[number];

/** Paper-doll gear slots (§7 — 6 slots; cape is level-locked). */
export const GEAR_SLOTS = ['helm', 'chest', 'main_hand', 'off_hand', 'boots', 'cape'] as const;
export type GearSlot = (typeof GEAR_SLOTS)[number];

/** Ability affinity tags (§3 weak/resist axis). */
export const ABILITY_TAGS = ['BONK', 'ZAP', 'SHELL', 'CHILL', 'EMBER', 'VOID'] as const;
export type AbilityTag = (typeof ABILITY_TAGS)[number];

// ---- characters (the shell's 8; face ids match assets/ui/faces/face-<id>.png) ----

export interface CharacterDef {
  name: string;
  epithet: string;
  flavor: string;
  bars: { atk: number; def: number; spd: number };
  mostPlayed: boolean;
  unlockLevel: number;
  unlockHint?: string;
}

export const CHARACTERS = {
  knight: {
    name: 'SIR BONKALOT',
    epithet: 'THE BONKSMITH',
    flavor: 'Hits things with a hammer until they stop being a problem. Excellent at doors.',
    bars: { atk: 0.88, def: 0.7, spd: 0.34 },
    mostPlayed: true,
    unlockLevel: 1,
  },
  huntress: {
    name: 'LADY STABBINGTON',
    epithet: 'THE POKEY ONE',
    flavor: "Believes most problems are just targets that haven't been introduced yet.",
    bars: { atk: 0.8, def: 0.42, spd: 0.72 },
    mostPlayed: false,
    unlockLevel: 1,
  },
  mage: {
    name: 'MAGEMIKE',
    epithet: 'SPARK GOBLIN',
    flavor: 'Learned exactly one lightning spell. Really commits to it.',
    bars: { atk: 0.76, def: 0.3, spd: 0.55 },
    mostPlayed: false,
    unlockLevel: 1,
  },
  barbarian: {
    name: 'BIG ANGRY DOUG',
    epithet: 'THE LOUD ONE',
    flavor: "Negotiates exclusively in shouting. It works more often than you'd think.",
    bars: { atk: 0.95, def: 0.55, spd: 0.28 },
    mostPlayed: false,
    unlockLevel: 1,
  },
  archer: {
    name: 'FLETCHLING',
    epithet: 'THE QUIVER KID',
    flavor: 'Never misses. Frequently loses the arrows afterward anyway.',
    bars: { atk: 0.72, def: 0.36, spd: 0.82 },
    mostPlayed: false,
    unlockLevel: 1,
  },
  druid: {
    name: 'TWIGBY',
    epithet: 'BRANCH MANAGER',
    flavor: "Speaks fluent squirrel. The squirrels wish he wouldn't.",
    bars: { atk: 0.5, def: 0.62, spd: 0.6 },
    mostPlayed: false,
    unlockLevel: 1,
  },
  beardruid: {
    name: 'MOSSBEARD',
    epithet: 'THE SNOOZY SAGE',
    flavor: "Older than the park. Naps like it's a competitive sport.",
    bars: { atk: 0.44, def: 0.85, spd: 0.22 },
    mostPlayed: false,
    unlockLevel: 1,
  },
  dwarf: {
    name: 'GRUMBEARD',
    epithet: 'THE UNMOVED',
    flavor: 'Has strong opinions about rocks and stronger ones about everything else.',
    bars: { atk: 0.66, def: 0.9, spd: 0.2 },
    mostPlayed: false,
    unlockLevel: 15,
    unlockHint: 'Grumbeard unlocks at LV 15',
  },
} as const satisfies Record<string, CharacterDef>;

export type CharacterId = keyof typeof CHARACTERS;

// ---- items (DATA-MODEL Item shape) ----

export interface ItemStats {
  atk?: number;
  def?: number;
  hp?: number;
  spd?: number;
  critPct?: number;
}

export interface ItemEffect {
  dmg?: number;
  targets?: number;
  cooldownSec?: number;
  blockSec?: number;
  reflectPct?: number;
  slowSec?: number;
  healHp?: number;
  charges?: number;
  knockbackHexes?: number;
}

export interface ItemDef {
  name: string;
  rarity: ItemRarity;
  rarityLabel?: string;
  slotType: SlotType;
  icon: string;
  abilityTag?: AbilityTag;
  stats: ItemStats;
  effect: ItemEffect;
  setTag?: string;
  levelReq?: number;
  sourceHint?: string;
  value: number;
  effectLine: string;
}

export const ITEMS = {
  bonk_hammer: {
    name: 'Bonk Hammer',
    rarity: 'rare',
    slotType: 'weapon',
    icon: 'hammer',
    abilityTag: 'BONK',
    stats: { atk: 14 },
    effect: { dmg: 24, knockbackHexes: 1 },
    setTag: 'hammer',
    value: 320,
    effectLine: '24 dmg · knocks back 1 hex',
  },
  zap_scroll: {
    name: 'Zap Scroll',
    rarity: 'rare',
    slotType: 'spell',
    icon: 'scroll',
    abilityTag: 'ZAP',
    stats: { atk: 4 },
    effect: { dmg: 12, targets: 3, cooldownSec: 8 },
    value: 260,
    effectLine: '12 dmg to up to 3 mobs · 8 s cooldown',
  },
  turtle_up: {
    name: 'Turtle Up',
    rarity: 'common',
    slotType: 'spell',
    icon: 'shield',
    abilityTag: 'SHELL',
    stats: {},
    effect: { blockSec: 3, reflectPct: 20, cooldownSec: 12 },
    value: 180,
    effectLine: 'blocks all damage for 3 s · reflects 20% · 12 s cooldown',
  },
  pocket_blizzard: {
    name: 'Pocket Blizzard',
    rarity: 'rare',
    slotType: 'spell',
    icon: 'snowflake',
    abilityTag: 'CHILL',
    stats: {},
    effect: { dmg: 18, slowSec: 3, cooldownSec: 8 },
    levelReq: 13,
    value: 340,
    effectLine: '18 dmg cone · slows mobs for 3 s · 8 s cooldown',
  },
  fizzy_mender: {
    name: 'Fizzy Mender',
    rarity: 'common',
    slotType: 'consumable',
    icon: 'potion',
    stats: {},
    effect: { healHp: 40, charges: 3 },
    value: 40,
    effectLine: 'heals 40 HP · 3 charges',
  },
  soggy_fireball: {
    name: 'Soggy Fireball',
    rarity: 'common',
    slotType: 'spell',
    icon: 'wand',
    abilityTag: 'EMBER',
    stats: {},
    effect: { dmg: 9, cooldownSec: 6 },
    value: 90,
    effectLine: '9 dmg · fizzles when it rains · 6 s cooldown',
  },
  gloom_vacuum: {
    name: 'Gloom Vacuum',
    rarity: 'epic',
    slotType: 'spell',
    icon: 'sparkle',
    abilityTag: 'VOID',
    stats: {},
    effect: { dmg: 14, targets: 4, cooldownSec: 10 },
    value: 900,
    effectLine: 'pulls 4 mobs 1 hex closer · 14 dmg · 10 s cooldown',
  },
  static_cling: {
    name: 'Static Cling',
    rarity: 'common',
    slotType: 'spell',
    icon: 'wand',
    abilityTag: 'ZAP',
    stats: {},
    effect: { dmg: 6, targets: 2, cooldownSec: 5 },
    value: 80,
    effectLine: '6 dmg jumps to 2 mobs · 5 s cooldown',
  },
  gloom_chest_spell: {
    name: '???',
    rarity: 'rare',
    slotType: 'spell',
    icon: 'lock',
    stats: {},
    effect: {},
    levelReq: 15,
    sourceHint: 'Found in Gloom chests',
    value: 0,
    effectLine: 'Found in Gloom chests · LV 15',
  },
  hammered_helm: {
    name: 'Hammered Helm',
    rarity: 'rare',
    slotType: 'helm',
    icon: 'shield',
    stats: { hp: 30, def: 6 },
    effect: {},
    setTag: 'hammer',
    value: 210,
    effectLine: '+30 HP · +6 DEF',
  },
  grumble_plate: {
    name: 'Grumbleforged Chestplate',
    rarity: 'epic',
    slotType: 'chest',
    icon: 'shield',
    stats: { hp: 22, def: 8 },
    effect: {},
    value: 780,
    effectLine: '+22 HP · +8 DEF',
  },
  sneaky_boots: {
    name: 'Sneaky Sneakers',
    rarity: 'common',
    slotType: 'boots',
    icon: 'steps',
    stats: { spd: 2 },
    effect: {},
    value: 120,
    effectLine: '+2 SPD',
  },
  cape_of_mild_dramatics: {
    name: 'Cape of Mild Dramatics',
    rarity: 'epic',
    slotType: 'cape',
    icon: 'sparkle',
    stats: { spd: 4 },
    effect: {},
    levelReq: 15,
    value: 2400,
    effectLine: '+4 SPD · billows dramatically indoors',
  },
  thwack_o_matic: {
    name: 'Thwack-o-matic 3000',
    rarity: 'rare',
    slotType: 'weapon',
    icon: 'hammer',
    abilityTag: 'BONK',
    stats: { atk: 18 },
    effect: { dmg: 28, knockbackHexes: 1 },
    setTag: 'hammer',
    value: 450,
    effectLine: '28 dmg · warranty void where thwacked',
  },
  fizzy_bucket: {
    name: 'Bucket of Fizzy Menders ×5',
    rarity: 'common',
    slotType: 'consumable',
    icon: 'potion',
    stats: {},
    effect: { healHp: 40, charges: 5 },
    value: 120,
    effectLine: '5 Fizzy Menders · heal 40 HP each',
  },
  mystery_box: {
    name: 'Mystery Grumble Box',
    rarity: 'mystery',
    rarityLabel: '???',
    slotType: 'consumable',
    icon: 'chest',
    stats: {},
    effect: {},
    value: 199,
    effectLine: 'random item · rarity-weighted',
  },
  grippy_gauntlets: {
    name: 'Grippy Gauntlets',
    rarity: 'rare',
    slotType: 'off_hand',
    icon: 'shield',
    stats: { atk: 3, critPct: 2 },
    effect: {},
    value: 300,
    effectLine: '+3 ATK · +2% CRIT · very grippy',
  },
  crown_of_grumbling: {
    name: 'Crown of Grumbling',
    rarity: 'legendary',
    slotType: 'helm',
    icon: 'star',
    stats: { hp: 40, def: 10 },
    effect: {},
    value: 1800,
    effectLine: '+40 HP · +10 DEF · radiates mild disapproval',
  },
  spare_grumble: {
    name: 'Spare Grumble',
    rarity: 'common',
    slotType: 'consumable',
    icon: 'question',
    stats: {},
    effect: {},
    value: 25,
    effectLine: 'a grumble, in case you run out',
  },
  turret_gearbox: {
    name: 'Turret Gearbox',
    rarity: 'rare',
    slotType: 'consumable',
    icon: 'gear',
    stats: {},
    effect: {},
    value: 150,
    effectLine: 'next Bonk Turret upgrade −25% cost',
  },
  unopened_chest: {
    name: 'Unopened Chest',
    rarity: 'common',
    slotType: 'consumable',
    icon: 'chest',
    stats: {},
    effect: {},
    value: 0,
    effectLine: 'you left this behind',
  },
} as const satisfies Record<string, ItemDef>;

export type ItemId = keyof typeof ITEMS;

// ---- gear sets (§7 — v1 ships exactly one) ----

export interface SetDef {
  name: string;
  piecesTotal: number;
  bonusPct: number;
  bonusLine: string;
}

export const SETS = {
  hammer: {
    name: 'HAMMER SET',
    piecesTotal: 4,
    bonusPct: 10,
    bonusLine: 'equip 2 more pieces for +10% knockback',
  },
} as const satisfies Record<string, SetDef>;

export type SetTag = keyof typeof SETS;

// ---- towers (§8) — costs must equal tuning §8 (cross-checked in tests) ----

export interface TowerDef {
  name: string;
  emoji: string;
  cost: number;
  tagline: string;
  effectLine: string;
  dmgPerTick?: number;
  slowPct?: number;
  radiusHexes: number;
}

export const TOWERS = {
  bonk_turret: {
    name: 'Bonk Turret',
    emoji: '🔨',
    cost: 12,
    tagline: 'single-target dmg',
    effectLine: '8 dmg per tick · radius 2 hexes',
    dmgPerTick: 8,
    radiusHexes: 2,
  },
  chill_bell: {
    name: 'Chill Bell',
    emoji: '🔔',
    cost: 18,
    tagline: 'AoE slow',
    effectLine: 'slows Gloomlings 40% in 2 hexes',
    slowPct: 40,
    radiusHexes: 2,
  },
  bastion_post: {
    name: 'Bastion Post',
    emoji: '🏰',
    cost: 30,
    tagline: "hexes can't flip",
    effectLine: 'hexes in radius 1 cannot flip while it stands',
    radiusHexes: 1,
  },
} as const satisfies Record<string, TowerDef>;

export type TowerTypeId = keyof typeof TOWERS;

// ---- minions (§9 — the 2 starters; a hired 3rd reuses a def) ----

export interface MinionDef {
  name: string;
  face: CharacterId;
  bio: string;
  quotes: readonly string[];
}

export const MINIONS = {
  gruncle: {
    name: 'Gruncle',
    face: 'dwarf',
    bio: 'Semi-retired mole. Knows where the good lumber is.',
    quotes: ["Lumber's heavier than it used to be. Or I'm older. Both."],
  },
  pip: {
    name: 'Pip',
    face: 'druid',
    bio: 'Enthusiastic mushroom. Easily distracted, cheap.',
    quotes: ["Found the front! Forgot where. It'll come back to me."],
  },
} as const satisfies Record<string, MinionDef>;

export type MinionDefId = keyof typeof MINIONS;

// ---- minion jobs (§9) ----

export interface JobDef {
  name: string;
  emoji: string;
  durationLabel: string;
  durationMin: number;
  outputLine: string;
  yieldMin?: number;
  yieldMax?: number;
  yieldBonusPct?: number;
  injuryPct: number;
  riskLine?: string;
}

export const JOBS = {
  gather_lumber: {
    name: 'Gather Lumber',
    emoji: '🪵',
    durationLabel: '~30 min',
    durationMin: 30,
    outputLine: 'returns 10–16 🪵',
    yieldMin: 10,
    yieldMax: 16,
    injuryPct: 0,
  },
  scout_front: {
    name: 'Scout the Front',
    emoji: '🧭',
    durationLabel: '~15 min',
    durationMin: 15,
    outputLine: 'reveals Gloom buildup on one front',
    injuryPct: 0,
  },
  scavenge: {
    name: 'Scavenge Contested Ground',
    emoji: '⚙️',
    durationLabel: '~1 h',
    durationMin: 60,
    outputLine: '🪵 +50% yield + tower salvage',
    yieldBonusPct: 50,
    injuryPct: 20,
    riskLine: '⚠️ 20% INJURY',
  },
} as const satisfies Record<string, JobDef>;

export type JobId = keyof typeof JOBS;

// ---- quests (§10) ----

export type QuestTab = 'daily' | 'story' | 'territory';

export interface QuestDef {
  tab: QuestTab;
  title: string;
  flavor: string;
  objective: string;
  target: number;
  rewardGold: number;
  pin: string;
  frontId?: string;
  chipLabel?: string;
  rewardItem?: boolean;
  rewardLabel?: string;
  giver?: string;
}

export const QUESTS = {
  daily_walk: {
    tab: 'daily',
    title: 'WALK 2,000 STEPS',
    flavor: 'Walk 2,000 steps in one day.',
    objective: 'Walk 2,000 steps',
    target: 2000,
    rewardGold: 80,
    pin: 'red',
  },
  daily_defeat: {
    tab: 'daily',
    title: 'DEFEAT 5 GLOOMLINGS',
    flavor: 'Defeat any 5 Gloomling mobs.',
    objective: 'Defeat 5 Gloomlings',
    target: 5,
    rewardGold: 120,
    pin: 'blue',
  },
  territory_elm: {
    tab: 'territory',
    title: 'CLAIM ELM STREET',
    flavor: 'Claim 5 Elm St hexes in one run.',
    objective: 'Claim 5 Elm St hexes in one run',
    target: 5,
    rewardGold: 200,
    pin: 'green',
    frontId: 'elm_st',
  },
  story_grumble_park: {
    tab: 'story',
    title: 'CLEAR GRUMBLE PARK',
    chipLabel: 'QUEST: Clear Grumble Park',
    flavor: 'Evict the Grumbleshroom and take back the napping bench.',
    objective: 'Defeat the Grumbleshroom in Grumble Park',
    target: 1,
    rewardGold: 300,
    rewardItem: true,
    rewardLabel: '300 gold + item',
    pin: 'gold',
    giver: 'elder_grumblesnore',
  },
} as const satisfies Record<string, QuestDef>;

export type QuestId = keyof typeof QUESTS;

// ---- mobs (§3) ----

export interface MobDef {
  name: string;
  title: string;
  level: number;
  isTyrant: boolean;
  hpSegments: number;
  hexesHeld: number;
  threatStars: number;
  lootRarityHint: string;
  weakTags: readonly AbilityTag[];
  resistTags: readonly AbilityTag[];
  weaknessLine: string;
  bio: string;
}

export const MOBS = {
  grumbleshroom: {
    name: 'GRUMBLESHROOM',
    title: 'TURF TYRANT',
    level: 8,
    isTyrant: true,
    hpSegments: 4,
    hexesHeld: 6,
    threatStars: 2,
    lootRarityHint: 'RARE',
    weakTags: ['BONK'],
    resistTags: ['ZAP'],
    weaknessLine: 'Weak to BONK · resists ZAP',
    bio: 'A fungus with opinions. Has been quietly annexing Grumble Park since Tuesday.',
  },
  gloomling: {
    name: 'GLOOMLING',
    title: 'GLOOMLING',
    level: 3,
    isTyrant: false,
    hpSegments: 1,
    hexesHeld: 1,
    threatStars: 1,
    lootRarityHint: 'COMMON',
    weakTags: ['BONK'],
    resistTags: [],
    weaknessLine: 'Weak to BONK',
    bio: 'A small lump of concentrated bad mood. Travels in grumbles.',
  },
} as const satisfies Record<string, MobDef>;

export type MobSpeciesId = keyof typeof MOBS;

// ---- NPCs ----

export interface NpcReply {
  label: string;
  kind: 'primary' | 'secondary' | 'tertiary';
}

export interface NpcDef {
  name: string;
  title: string;
  face: CharacterId;
  merchant: boolean;
  line: string;
  questId?: QuestId;
  replies?: readonly NpcReply[];
  restockNote?: string;
}

export const NPCS = {
  elder_grumblesnore: {
    name: 'ELDER GRUMBLESNORE',
    title: 'KEEPER OF THE TURF',
    face: 'beardruid',
    merchant: false,
    line: '"The Gloomlings took the park, the plaza, AND my favorite napping bench. This is a bench-related emergency, adventurer."',
    questId: 'story_grumble_park',
    replies: [
      { label: 'ACCEPT QUEST', kind: 'primary' },
      { label: 'VIEW REWARD DETAILS', kind: 'secondary' },
      { label: 'DECLINE', kind: 'tertiary' },
    ],
  },
  grumbeard: {
    name: "GRUMBEARD'S GRUMBLEMART",
    title: 'ROAMING MERCHANT',
    face: 'dwarf',
    merchant: true,
    line: '"Fresh loot! Barely cursed! No refunds if it bites."',
    restockNote: 'Shop restocks when you visit a new neighborhood',
  },
} as const satisfies Record<string, NpcDef>;

export type NpcId = keyof typeof NPCS;

// ---- shop stock (§11; order is the shelf order in the mock) ----

export interface ShopStockEntry {
  item: ItemId;
  dealPct?: number;
  dealBadge?: string;
}

export const SHOP_STOCK: readonly ShopStockEntry[] = [
  { item: 'thwack_o_matic' },
  { item: 'fizzy_bucket', dealPct: 30, dealBadge: '-30% TODAY' },
  { item: 'cape_of_mild_dramatics' },
  { item: 'mystery_box' },
];

// ---- starting loadout (mirrors game/src/data/game_state.gd's shell state) ----

/** New-player hotbar, slot order fixed (slot 0 is the ATTACK-button weapon). null = empty slot. */
export const DEFAULT_HOTBAR: readonly (ItemId | null)[] = [
  'bonk_hammer',
  'zap_scroll',
  'turtle_up',
  'fizzy_mender',
  null,
];

// ---- loot pool (§6) — droppable item ids by rarity tier. The staged chest roll and
// mob drops draw from these via tuning's rarity weights. Deliberately excluded:
// mystery_box (shop-only), gloom_chest_spell (locked '???' placeholder),
// unopened_chest (run-summary display token). ----

export const LOOT_POOL: Record<Rarity, readonly ItemId[]> = {
  common: [
    'turtle_up',
    'fizzy_mender',
    'soggy_fireball',
    'static_cling',
    'sneaky_boots',
    'spare_grumble',
    'fizzy_bucket',
  ],
  rare: [
    'bonk_hammer',
    'zap_scroll',
    'pocket_blizzard',
    'hammered_helm',
    'thwack_o_matic',
    'grippy_gauntlets',
    'turret_gearbox',
  ],
  epic: ['gloom_vacuum', 'grumble_plate', 'cape_of_mild_dramatics'],
  legendary: ['crown_of_grumbling'],
};

// ---- lookups (undefined on unknown id — callers decide whether that's an ERR) ----

export function itemDef(id: string): ItemDef | undefined {
  return (ITEMS as Record<string, ItemDef>)[id];
}

export function characterDef(id: string): CharacterDef | undefined {
  return (CHARACTERS as Record<string, CharacterDef>)[id];
}

export function towerDef(id: string): TowerDef | undefined {
  return (TOWERS as Record<string, TowerDef>)[id];
}

export function minionDef(id: string): MinionDef | undefined {
  return (MINIONS as Record<string, MinionDef>)[id];
}

export function jobDef(id: string): JobDef | undefined {
  return (JOBS as Record<string, JobDef>)[id];
}

export function questDef(id: string): QuestDef | undefined {
  return (QUESTS as Record<string, QuestDef>)[id];
}

export function mobDef(id: string): MobDef | undefined {
  return (MOBS as Record<string, MobDef>)[id];
}

export function npcDef(id: string): NpcDef | undefined {
  return (NPCS as Record<string, NpcDef>)[id];
}

export function setDef(tag: string): SetDef | undefined {
  return (SETS as Record<string, SetDef>)[tag];
}
