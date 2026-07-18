// sim/commands_economy.ts — reducer handlers for the economy ops: shop (BUY/SELL),
// towers (§8), minions (§9), quests (§10), party (§12). Import-for-side-effect:
// loading this module plugs the handlers into the sim/commands registry (and, via
// systems/minions, the minion ticker into the tick order). All VALIDATION lives
// here — illegal intent returns one ERR frame and mutates nothing; the systems'
// mutators assume gates passed.

import type { Player, Tower, World } from '../shared/entities.js';
import type { ServerMsg } from '../shared/protocol.js';
import { OP } from '../shared/protocol.js';
import type { CommandCtx } from './commands.js';
import { boundPlayer, err, registerHandler } from './commands.js';
import { buildInventoryUpdate } from './world.js';
import { itemDef, TOWERS } from '../shared/catalog.js';
import {
  MINION_HEAL_COST,
  MINION_HIRE_COST,
  PARTY_MAX,
  TOWER_CAP,
  TOWER_MAX_LEVEL,
  TOWER_REPAIR_COST,
  TOWER_UPGRADE_COST,
  sellValue,
  towerDurabilityMax,
} from '../shared/tuning.js';
import { parseHexKey } from '../shared/hexgrid.js';
import {
  buildShopResult,
  grantItem,
  isEquipped,
  rollMysteryItem,
  shopStock,
} from './systems/shop.js';
import {
  isStandingOn,
  ownedTowers,
  placeTower,
  removeTower,
  repairAllTowers,
  repairTower,
  retargetTower,
  salvageTower,
  towerAtHex,
  towerCost,
  upgradeTower,
} from './systems/towers.js';
import {
  MINION_ROSTER_MAX,
  findMinion,
  healMinion,
  hireMinion,
  resolveJob,
  rosterOf,
  sendMinion,
} from './systems/minions.js';
import { claimQuest, refreshQuestStates } from './systems/quests.js';
import { parseFrontId } from './systems/fronts.js';
import {
  buildPartyUpdate,
  createParty,
  findPartyByCode,
  joinParty,
  leaveParty,
  pushPartyUpdate,
} from './systems/party.js';

function noSession(now: number, refOp: number): ServerMsg[] {
  return [err(now, 'SESSION_UNKNOWN', 'no player bound to this connection', refOp)];
}

// ---------------------------------------------------------------------------
// §11 shop
// ---------------------------------------------------------------------------

registerHandler(OP.BUY, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const entry = shopStock(world, self).find((s) => s.itemId === cmd.itemId);
  if (!entry) return [err(ctx.now, 'NOT_FOUND', `'${cmd.itemId}' is not in stock`, cmd.op)];
  if (self.gold < entry.price) {
    return [err(ctx.now, 'INSUFFICIENT_GOLD', `need ${entry.price} gold, have ${self.gold}`, cmd.op)];
  }
  self.gold -= entry.price;
  const frames: ServerMsg[] = [];
  if (cmd.itemId === 'mystery_box') {
    const roll = rollMysteryItem(ctx.rng);
    grantItem(self, roll.itemId, ctx.genId('item'));
    frames.push({
      op: OP.LOOT_RESULT,
      t: ctx.now,
      sourceId: 'mystery_box',
      items: [{ itemId: roll.itemId, rarity: roll.rarity }],
      gold: 0,
      xp: 0,
    });
  } else {
    grantItem(self, cmd.itemId, ctx.genId('item'));
  }
  self.updatedAt = ctx.now;
  frames.push(buildShopResult(world, self, ctx.now), buildInventoryUpdate(self, ctx.now));
  return frames;
});

registerHandler(OP.SELL, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const idx = self.inventory.findIndex((i) => i.iid === cmd.iid);
  if (idx < 0) return [err(ctx.now, 'NOT_FOUND', 'item not in inventory', cmd.op)];
  if (isEquipped(self, cmd.iid)) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'unequip before selling', cmd.op)];
  }
  const inst = self.inventory[idx];
  self.inventory.splice(idx, 1);
  self.gold += sellValue(itemDef(inst.itemId)?.value ?? 0);
  self.updatedAt = ctx.now;
  return [buildShopResult(world, self, ctx.now), buildInventoryUpdate(self, ctx.now)];
});

// ---------------------------------------------------------------------------
// §8 towers
// ---------------------------------------------------------------------------

registerHandler(OP.TOWER_BUILD, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (!parseHexKey(cmd.hexKey)) return [err(ctx.now, 'BAD_REQUEST', 'malformed hex key', cmd.op)];
  if (!isStandingOn(self, cmd.hexKey)) {
    return [err(ctx.now, 'OUT_OF_RANGE', 'stand on the hex to build', cmd.op)];
  }
  if (world.hexes.get(cmd.hexKey)?.owner !== 'players') {
    return [err(ctx.now, 'ILLEGAL_STATE', 'hex is not player-owned', cmd.op)];
  }
  const existing = towerAtHex(world, cmd.hexKey);
  if (existing && !existing.isRubble) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'hex already has a tower', cmd.op)];
  }
  if (existing && existing.ownerId !== self.id) {
    return [err(ctx.now, 'ILLEGAL_STATE', "another player's rubble holds this hex", cmd.op)];
  }
  const count = ownedTowers(world, self.id).filter((t) => t !== existing).length;
  if (count >= TOWER_CAP) {
    return [err(ctx.now, 'CAP_REACHED', `tower cap is ${TOWER_CAP}`, cmd.op)];
  }
  const cost = towerCost(cmd.type);
  if (self.materials < cost) {
    return [err(ctx.now, 'INSUFFICIENT_MATERIALS', `need ${cost} 🪵, have ${self.materials}`, cmd.op)];
  }
  // Rebuild consumes the rubble outright (no refund — salvage first for the ~40%).
  if (existing) removeTower(world, existing);
  placeTower(world, self, cmd.type, cmd.hexKey, { now: ctx.now, genId: ctx.genId });
  return [buildInventoryUpdate(self, ctx.now)];
});

/** Shared lookup: the tower must exist and be the caller's. */
function ownTower(
  world: World,
  self: Player,
  towerId: string,
  ctx: CommandCtx,
  refOp: number,
): { tower: Tower } | { errFrames: ServerMsg[] } {
  const tower = world.towers.get(towerId);
  if (!tower) return { errFrames: [err(ctx.now, 'NOT_FOUND', 'no such tower', refOp)] };
  if (tower.ownerId !== self.id) {
    return { errFrames: [err(ctx.now, 'ILLEGAL_STATE', 'not your tower', refOp)] };
  }
  return { tower };
}

registerHandler(OP.TOWER_REPAIR, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const found = ownTower(world, self, cmd.towerId, ctx, cmd.op);
  if ('errFrames' in found) return found.errFrames;
  const { tower } = found;
  if (tower.isRubble) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'rubble — rebuild requires a visit', cmd.op)];
  }
  if (tower.durability >= towerDurabilityMax(tower.level)) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'already at full durability', cmd.op)];
  }
  if (self.materials < TOWER_REPAIR_COST) {
    return [err(ctx.now, 'INSUFFICIENT_MATERIALS', `need ${TOWER_REPAIR_COST} 🪵`, cmd.op)];
  }
  repairTower(world, self, tower, ctx.now);
  return [buildInventoryUpdate(self, ctx.now)];
});

registerHandler(OP.TOWER_UPGRADE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const found = ownTower(world, self, cmd.towerId, ctx, cmd.op);
  if ('errFrames' in found) return found.errFrames;
  const { tower } = found;
  if (tower.isRubble) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'rubble — rebuild requires a visit', cmd.op)];
  }
  if (tower.level >= TOWER_MAX_LEVEL) {
    return [err(ctx.now, 'CAP_REACHED', `max level is ${TOWER_MAX_LEVEL}`, cmd.op)];
  }
  if (self.materials < TOWER_UPGRADE_COST) {
    return [err(ctx.now, 'INSUFFICIENT_MATERIALS', `need ${TOWER_UPGRADE_COST} 🪵`, cmd.op)];
  }
  upgradeTower(world, self, tower, ctx.now);
  return [buildInventoryUpdate(self, ctx.now)];
});

registerHandler(OP.TOWER_SALVAGE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const found = ownTower(world, self, cmd.towerId, ctx, cmd.op);
  if ('errFrames' in found) return found.errFrames;
  salvageTower(world, self, found.tower, ctx.now);
  return [buildInventoryUpdate(self, ctx.now)];
});

registerHandler(OP.TOWER_TARGET, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const found = ownTower(world, self, cmd.towerId, ctx, cmd.op);
  if ('errFrames' in found) return found.errFrames;
  retargetTower(found.tower, cmd.priority);
  return [];
});

registerHandler(OP.TOWER_REPAIR_ALL, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const damaged = ownedTowers(world, self.id).filter(
    (t) => !t.isRubble && t.durability < towerDurabilityMax(t.level),
  );
  if (damaged.length === 0) return [err(ctx.now, 'ILLEGAL_STATE', 'nothing to repair', cmd.op)];
  if (self.materials < TOWER_REPAIR_COST) {
    return [err(ctx.now, 'INSUFFICIENT_MATERIALS', `need ${TOWER_REPAIR_COST} 🪵`, cmd.op)];
  }
  repairAllTowers(world, self, ctx.now);
  return [buildInventoryUpdate(self, ctx.now)];
});

// ---------------------------------------------------------------------------
// §9 minions
// ---------------------------------------------------------------------------

registerHandler(OP.MINION_SEND, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const minion = findMinion(world, self.id, cmd.minionId);
  if (!minion) return [err(ctx.now, 'NOT_FOUND', 'no such minion', cmd.op)];
  if (minion.state === 'injured') {
    return [err(ctx.now, 'ILLEGAL_STATE', 'injured — heal first', cmd.op)];
  }
  if (minion.state === 'on_job') {
    return [err(ctx.now, 'ILLEGAL_STATE', 'already on a job', cmd.op)];
  }
  if (cmd.jobId === 'scout_front' && (!cmd.frontId || !parseFrontId(cmd.frontId))) {
    return [err(ctx.now, 'BAD_REQUEST', 'scout needs a front', cmd.op)];
  }
  sendMinion(minion, cmd.jobId, cmd.jobId === 'scout_front' ? cmd.frontId : undefined, ctx.now);
  return [];
});

registerHandler(OP.MINION_COLLECT, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const minion = findMinion(world, self.id, cmd.minionId);
  if (!minion) return [err(ctx.now, 'NOT_FOUND', 'no such minion', cmd.op)];
  if (minion.state !== 'on_job' || !minion.job) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'no job to collect', cmd.op)];
  }
  if (ctx.now < minion.job.endsAt) {
    return [err(ctx.now, 'ILLEGAL_STATE', 'still working', cmd.op)];
  }
  const report = resolveJob(world, self, minion, { now: ctx.now, rng: ctx.rng, genId: ctx.genId });
  return [report, buildInventoryUpdate(self, ctx.now)];
});

registerHandler(OP.MINION_HIRE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (rosterOf(world, self.id).length >= MINION_ROSTER_MAX) {
    return [err(ctx.now, 'CAP_REACHED', `roster cap is ${MINION_ROSTER_MAX}`, cmd.op)];
  }
  if (self.gold < MINION_HIRE_COST) {
    return [err(ctx.now, 'INSUFFICIENT_GOLD', `need ${MINION_HIRE_COST} gold`, cmd.op)];
  }
  hireMinion(world, self, { now: ctx.now, rng: ctx.rng, genId: ctx.genId });
  return [buildInventoryUpdate(self, ctx.now)];
});

registerHandler(OP.MINION_HEAL, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const minion = findMinion(world, self.id, cmd.minionId);
  if (!minion) return [err(ctx.now, 'NOT_FOUND', 'no such minion', cmd.op)];
  if (minion.state !== 'injured') return [err(ctx.now, 'ILLEGAL_STATE', 'not injured', cmd.op)];
  if (self.gold < MINION_HEAL_COST) {
    return [err(ctx.now, 'INSUFFICIENT_GOLD', `need ${MINION_HEAL_COST} gold`, cmd.op)];
  }
  healMinion(self, minion, ctx.now);
  return [buildInventoryUpdate(self, ctx.now)];
});

// ---------------------------------------------------------------------------
// §10 quests
// ---------------------------------------------------------------------------

registerHandler(OP.QUEST_CLAIM, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  const qp = self.quests[cmd.questId];
  if (!qp) return [err(ctx.now, 'NOT_FOUND', 'quest not on your board', cmd.op)];
  refreshQuestStates(self);
  if (qp.state === 'done') return [err(ctx.now, 'ILLEGAL_STATE', 'already claimed', cmd.op)];
  if (qp.state !== 'claimable') return [err(ctx.now, 'ILLEGAL_STATE', 'quest not complete', cmd.op)];
  return claimQuest(world, self, cmd.questId, { now: ctx.now, rng: ctx.rng, genId: ctx.genId });
});

// ---------------------------------------------------------------------------
// §12 party
// ---------------------------------------------------------------------------

registerHandler(OP.PARTY_CREATE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.partyId !== null) return [err(ctx.now, 'ILLEGAL_STATE', 'already in a party', cmd.op)];
  const party = createParty(world, self, { now: ctx.now, rng: ctx.rng, genId: ctx.genId });
  return [buildPartyUpdate(world, party, ctx.now)];
});

registerHandler(OP.PARTY_JOIN, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.partyId !== null) return [err(ctx.now, 'ILLEGAL_STATE', 'already in a party', cmd.op)];
  const party = findPartyByCode(world, cmd.code);
  if (!party) return [err(ctx.now, 'NOT_FOUND', 'no party with that code', cmd.op)];
  if (party.memberIds.length >= PARTY_MAX) {
    return [err(ctx.now, 'CAP_REACHED', `party is full (max ${PARTY_MAX})`, cmd.op)];
  }
  joinParty(world, party, self, ctx.now);
  pushPartyUpdate(world, party, ctx.now, self.id);
  return [buildPartyUpdate(world, party, ctx.now)];
});

registerHandler(OP.PARTY_LEAVE, (world, cmd, ctx) => {
  const self = boundPlayer(world, ctx);
  if (!self) return noSession(ctx.now, cmd.op);
  if (self.partyId === null) return [err(ctx.now, 'ILLEGAL_STATE', 'not in a party', cmd.op)];
  const remaining = leaveParty(world, self, ctx.now);
  if (remaining) pushPartyUpdate(world, remaining, ctx.now);
  return [buildPartyUpdate(world, null, ctx.now)];
});
