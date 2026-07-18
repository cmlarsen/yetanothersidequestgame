// sim/systems/progression.ts — §7 progression & gear helpers. PURE, no clock, no rng.
// The canonical XP/gold award path (level-ups, stat bumps, LEVEL_UP frames, LV13/15
// unlocks) lives in territory.ts's grantXp/grantGold — re-exported here so combat/
// chest/economy callers reach progression through one door without a second
// implementation drifting. This module owns what territory doesn't: gear-slot
// mapping, equip validation (level locks), and set-bonus aggregation (§7 hammer 2/4).

import type { Player } from '../../shared/entities.js';
import { GEAR_SLOTS, SETS, itemDef } from '../../shared/catalog.js';
import type { GearSlot, ItemDef, SetTag } from '../../shared/catalog.js';
import { CAPE_UNLOCK_LEVEL } from '../../shared/tuning.js';

export { grantXp, grantGold } from './territory.js';

/** The paper-doll slot an item can occupy (null = not gear: spells/consumables). */
export function gearSlotForItem(def: ItemDef): GearSlot | null {
  switch (def.slotType) {
    case 'weapon':
      return 'main_hand';
    case 'off_hand':
      return 'off_hand';
    case 'helm':
    case 'chest':
    case 'boots':
    case 'cape':
      return def.slotType;
    default:
      return null;
  }
}

export interface EquipProblem {
  message: string;
}

/** §3 hotbar slots hold weapons, spells, or consumables — level-locked items refuse. */
export function validateHotbarEquip(player: Player, def: ItemDef): EquipProblem | null {
  if (def.slotType !== 'weapon' && def.slotType !== 'spell' && def.slotType !== 'consumable') {
    return { message: 'only weapons, spells, and consumables go on the hot bar' };
  }
  if (def.levelReq !== undefined && player.level < def.levelReq) {
    return { message: `locked until LV ${def.levelReq}` };
  }
  return null;
}

/** §7 paper doll: slot compatibility + the LV15 cape-slot lock + item level locks. */
export function validateGearEquip(
  player: Player,
  def: ItemDef,
  gearSlot: GearSlot,
): EquipProblem | null {
  if (gearSlotForItem(def) !== gearSlot) {
    return { message: `that item does not fit the ${gearSlot} slot` };
  }
  if (gearSlot === 'cape' && player.level < CAPE_UNLOCK_LEVEL) {
    return { message: `cape slot unlocks at LV ${CAPE_UNLOCK_LEVEL}` };
  }
  if (def.levelReq !== undefined && player.level < def.levelReq) {
    return { message: `locked until LV ${def.levelReq}` };
  }
  return null;
}

/** §7 "sets count equipped pieces sharing the set tag" — paper doll only. */
export function setPieces(player: Player, tag: SetTag): number {
  let n = 0;
  for (const slot of GEAR_SLOTS) {
    const iid = player.equipment[slot];
    if (!iid) continue;
    const inst = player.inventory.find((i) => i.iid === iid);
    if (inst && itemDef(inst.itemId)?.setTag === tag) n += 1;
  }
  return n;
}

export interface SetProgress {
  pieces: number;
  total: number;
  active: boolean;
}

/** The HAMMER SET 2/4 flag (§7): active once every piece of the set is worn. */
export function setProgress(player: Player, tag: SetTag): SetProgress {
  const pieces = setPieces(player, tag);
  const total = SETS[tag].piecesTotal;
  return { pieces, total, active: pieces >= total };
}

/** Pure threshold form so the bonus math is testable past v1's 3 craftable pieces. */
export function knockbackMultiplierFromPieces(tag: SetTag, pieces: number): number {
  const def = SETS[tag];
  return pieces >= def.piecesTotal ? 1 + def.bonusPct / 100 : 1;
}

/** §7 hammer set bonus: +10% knockback when complete — combat scales the kb flavor. */
export function knockbackMultiplier(player: Player): number {
  return knockbackMultiplierFromPieces('hammer', setPieces(player, 'hammer'));
}
