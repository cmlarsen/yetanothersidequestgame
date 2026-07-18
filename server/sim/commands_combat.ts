// sim/commands_combat.ts — the combat/loot/equip intent handlers, registered into
// the commands.ts handler registry: ATTACK, USE_SLOT, FLEE, CHEST_OPEN, EQUIP
// (hotbar), EQUIP_GEAR (paper doll). Every illegal intent returns exactly one ERR
// frame with zero mutation (reducer contract). Importing this module wires the
// whole combat stack: mobs/combat/chests register their tickers + territory hooks
// at module load.

import type { Player } from '../shared/entities.js';
import type { ServerMsg } from '../shared/protocol.js';
import { OP } from '../shared/protocol.js';
import { GEAR_SLOTS, itemDef } from '../shared/catalog.js';
import { boundPlayer, err, registerHandler } from './commands.js';
import { buildInventoryUpdate, refreshMaxHp } from './world.js';
import { isSpeedPaused } from './systems/movement.js';
import { disengagePlayer, isEngaged, useSlot } from './systems/combat.js';
import { openChest } from './systems/chests.js';
import { validateGearEquip, validateHotbarEquip } from './systems/progression.js';

/** §2/§3/§14 gates shared by every run-scoped action (combat + chest opening):
 * alive, mid-run, and not speed-paused (driving guard disables combat too). */
function runActionGate(self: Player, now: number, refOp: number): ServerMsg | null {
  if (self.lifeState !== 'alive') return err(now, 'ILLEGAL_STATE', 'you are downed', refOp);
  if (!self.run) return err(now, 'ILLEGAL_STATE', 'start a run first', refOp);
  if (isSpeedPaused(self)) {
    return err(now, 'ILLEGAL_STATE', 'combat is paused while moving fast', refOp);
  }
  return null;
}

function noSession(now: number, refOp: number): ServerMsg[] {
  return [err(now, 'SESSION_UNKNOWN', 'no player bound to this connection', refOp)];
}

// ---------------------------------------------------------------------------
// ATTACK — the big button: triggers the slot-1 weapon (§3), named or nearest mob.
// ---------------------------------------------------------------------------

registerHandler(OP.ATTACK, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const gate = runActionGate(self, ctx.now, cmd.op);
  if (gate) return [gate];
  const iid = self.hotbar[0];
  const inst = iid ? self.inventory.find((i) => i.iid === iid) : undefined;
  const def = inst ? itemDef(inst.itemId) : undefined;
  if (!def || def.slotType !== 'weapon') {
    return [err(ctx.now, 'ILLEGAL_STATE', 'slot 1 holds no weapon', cmd.op)];
  }
  return useSlot(world, self, 0, cmd.mobId, cmd.op, ctx);
});

registerHandler(OP.USE_SLOT, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const gate = runActionGate(self, ctx.now, cmd.op);
  if (gate) return [gate];
  return useSlot(world, self, cmd.slot, cmd.mobId, cmd.op, ctx);
});

// ---------------------------------------------------------------------------
// FLEE — explicit disengage (§3; walking out past the buffer does it implicitly).
// ---------------------------------------------------------------------------

registerHandler(OP.FLEE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.lifeState !== 'alive') return [err(ctx.now, 'ILLEGAL_STATE', 'you are downed', cmd.op)];
  if (!isEngaged(world, self)) return [err(ctx.now, 'ILLEGAL_STATE', 'not in combat', cmd.op)];
  disengagePlayer(world, self);
  return [];
});

// ---------------------------------------------------------------------------
// CHEST_OPEN — §6 proximity-gated staged loot.
// ---------------------------------------------------------------------------

registerHandler(OP.CHEST_OPEN, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const gate = runActionGate(self, ctx.now, cmd.op);
  if (gate) return [gate];
  return openChest(world, self, cmd.chestId, cmd.op, ctx);
});

// ---------------------------------------------------------------------------
// EQUIP — hotbar slot ← inventory instance (null clears). Mid-combat swapping is
// allowed (§3 DEFAULT); the slot's cooldown stamp survives the swap so re-equipping
// can't reset a spell cooldown.
// ---------------------------------------------------------------------------

registerHandler(OP.EQUIP, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (cmd.iid === null) {
    self.hotbar[cmd.slot] = null;
    self.updatedAt = ctx.now;
    return [buildInventoryUpdate(self, ctx.now)];
  }
  const inst = self.inventory.find((i) => i.iid === cmd.iid);
  if (!inst) return [err(ctx.now, 'NOT_FOUND', 'you do not own that item', cmd.op)];
  const def = itemDef(inst.itemId);
  if (!def) return [err(ctx.now, 'BAD_REQUEST', `unknown item '${inst.itemId}'`, cmd.op)];
  const problem = validateHotbarEquip(self, def);
  if (problem) return [err(ctx.now, 'ILLEGAL_STATE', problem.message, cmd.op)];
  for (let s = 0; s < self.hotbar.length; s++) {
    if (self.hotbar[s] === cmd.iid) self.hotbar[s] = null; // an instance sits in one slot
  }
  self.hotbar[cmd.slot] = cmd.iid;
  inst.isNew = false;
  self.updatedAt = ctx.now;
  return [buildInventoryUpdate(self, ctx.now)];
});

// ---------------------------------------------------------------------------
// EQUIP_GEAR — paper-doll slot ← inventory instance (null clears). Slot
// compatibility + the LV15 cape lock + item level locks; maxHp recomputes.
// ---------------------------------------------------------------------------

registerHandler(OP.EQUIP_GEAR, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (cmd.iid === null) {
    self.equipment[cmd.gearSlot] = null;
    refreshMaxHp(self);
    self.updatedAt = ctx.now;
    return [buildInventoryUpdate(self, ctx.now)];
  }
  const inst = self.inventory.find((i) => i.iid === cmd.iid);
  if (!inst) return [err(ctx.now, 'NOT_FOUND', 'you do not own that item', cmd.op)];
  const def = itemDef(inst.itemId);
  if (!def) return [err(ctx.now, 'BAD_REQUEST', `unknown item '${inst.itemId}'`, cmd.op)];
  const problem = validateGearEquip(self, def, cmd.gearSlot);
  if (problem) return [err(ctx.now, 'ILLEGAL_STATE', problem.message, cmd.op)];
  for (const slot of GEAR_SLOTS) {
    if (self.equipment[slot] === cmd.iid) self.equipment[slot] = null;
  }
  self.equipment[cmd.gearSlot] = cmd.iid;
  inst.isNew = false;
  refreshMaxHp(self);
  self.updatedAt = ctx.now;
  return [buildInventoryUpdate(self, ctx.now)];
});
