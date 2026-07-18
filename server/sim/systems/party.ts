// sim/systems/party.ts — §12 party lifecycle: BONK-style join codes, membership,
// the PARTY_UPDATE fan-out, and the §5 revive-eligibility read the death flow
// consumes. PURE, CLOCK-INJECTED, SEED-DETERMINISTIC (codes come from the injected
// rng). Validation lives in sim/commands_economy.ts; mutators assume gates passed.

import type { Party, Player, World } from '../../shared/entities.js';
import type { PartyUpdateMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import { REVIVE_RADIUS_M } from '../../shared/tuning.js';
import { within } from '../../shared/geo.js';
import type { Rng } from '../../shared/rng.js';
import { buildPartyWire } from '../world.js';
import { isInCombat } from './territory.js';
import { pushEvent } from './outbox.js';

/** §12 "BONK-4242 style": a punchy prefix + 4 digits. */
export const PARTY_CODE_WORDS = [
  'BONK',
  'ZAP',
  'GRUM',
  'THWK',
  'MOSS',
  'DRIP',
  'TURF',
  'SNOR',
] as const;

/** Draw codes until one is free (8×9000 combos, collisions are vanishingly rare). */
export function mintPartyCode(world: World, rng: Rng): string {
  for (;;) {
    const code = `${rng.pick(PARTY_CODE_WORDS)}-${rng.int(1000, 9999)}`;
    if (![...world.parties.values()].some((p) => p.code === code)) return code;
  }
}

export function createParty(
  world: World,
  leader: Player,
  deps: { now: number; rng: Rng; genId: (kind: string) => string },
): Party {
  const party: Party = {
    id: deps.genId('party'),
    code: mintPartyCode(world, deps.rng),
    leaderId: leader.id,
    memberIds: [leader.id],
    createdAt: deps.now,
  };
  world.parties.set(party.id, party);
  leader.partyId = party.id;
  leader.updatedAt = deps.now;
  return party;
}

/** Case-insensitive code lookup (players read codes aloud). */
export function findPartyByCode(world: World, code: string): Party | undefined {
  const norm = code.trim().toUpperCase();
  return [...world.parties.values()].find((p) => p.code === norm);
}

export function joinParty(world: World, party: Party, player: Player, now: number): void {
  party.memberIds.push(player.id);
  player.partyId = party.id;
  player.updatedAt = now;
}

/** Leave (leader hand-off to the next member; empty party dissolves). Returns the
 * surviving party, or null when it dissolved. */
export function leaveParty(world: World, player: Player, now: number): Party | null {
  const party = player.partyId !== null ? world.parties.get(player.partyId) : undefined;
  player.partyId = null;
  player.updatedAt = now;
  if (!party) return null;
  party.memberIds = party.memberIds.filter((id) => id !== player.id);
  if (party.memberIds.length === 0) {
    world.parties.delete(party.id);
    return null;
  }
  if (party.leaderId === player.id) party.leaderId = party.memberIds[0];
  return party;
}

/** The op112 frame. Refines the world-core wire's online/offline with the §12
 * IN COMBAT state (the combat probe registered by the combat system). */
export function buildPartyUpdate(world: World, party: Party | null, now: number): PartyUpdateMsg {
  if (!party) return { op: OP.PARTY_UPDATE, t: now, party: null };
  const wire = buildPartyWire(world, party);
  for (const member of wire.members) {
    if (member.state !== 'online') continue;
    const p = world.players.get(member.id);
    if (p && isInCombat(world, p)) member.state = 'inCombat';
  }
  return { op: OP.PARTY_UPDATE, t: now, party: wire };
}

/** Fan a PARTY_UPDATE to every member (optionally skipping the command issuer,
 * who gets it as the direct reply). */
export function pushPartyUpdate(world: World, party: Party, now: number, exceptId?: string): void {
  const msg = buildPartyUpdate(world, party, now);
  for (const id of party.memberIds) {
    if (id === exceptId) continue;
    pushEvent(world, { to: id, msg });
  }
}

/** §5 revive eligibility: some other party member, online and alive, within
 * REVIVE_RADIUS_M of where the downed player fell. The death flow consumes this. */
export function reviveEligible(world: World, downed: Player): boolean {
  if (downed.partyId === null) return false;
  const party = world.parties.get(downed.partyId);
  if (!party) return false;
  for (const id of party.memberIds) {
    if (id === downed.id) continue;
    const member = world.players.get(id);
    if (!member || member.connId === null || member.lifeState !== 'alive') continue;
    if (within(member.pos, downed.pos, REVIVE_RADIUS_M)) return true;
  }
  return false;
}
