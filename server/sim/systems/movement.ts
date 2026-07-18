// sim/systems/movement.ts — the player movement system. PURE, CLOCK-INJECTED,
// deterministic. A GPS fix is a MOVE TARGET, never a teleport (DESIGN §GPS):
//
//   ingestGps(world, self, msg, now)   — reducer step (called from the GPS handler):
//       project the raw fix → local metres and stash it as `self.moveTarget`, running
//       the field-tested jitter guards (accuracy reject / deadband / relocation snap).
//   stepMovement(world, dtMs, now)     — tick step: ease every player toward its
//       target with exponential smoothing + a max-speed clamp.
//
// Ported from SideQuestAppV2 server/sim/systems/movement.ts (the WeakMap target
// store becomes the Player.moveTarget runtime field; facing/animState dropped —
// YAS wires carry position only; speed-pause flag added per GAME-RULES §14).

import type { Player, World } from '../../shared/entities.js';
import type { GpsMsg } from '../../shared/protocol.js';
import { project } from '../../shared/geo.js';
import {
  GPS_DEADBAND_M,
  GPS_REJECT_ACC_M,
  GPS_TELEPORT_M,
  MOVE_ARRIVE_EPS,
  MOVE_MAX_MPS,
  MOVE_SMOOTH_ALPHA,
} from '../../shared/constants.js';
import { SPEED_PAUSE_KMH } from '../../shared/tuning.js';

/**
 * ingestGps — project the fix to metres against World.origin and store it as the
 * move target; the tick loop does the actual easing. Rejects non-finite fixes
 * silently (a garbage frame must never corrupt a position). Also records reported
 * accuracy/speed/steps (the §14 speed-pause guard and pedometer ride the GPS stream).
 */
export function ingestGps(world: World, self: Player, msg: GpsMsg, now: number): void {
  if (msg.speedKmh !== undefined && Number.isFinite(msg.speedKmh)) self.speedKmh = msg.speedKmh;
  if (msg.steps !== undefined) self.stepsToday = msg.steps;
  if (!Number.isFinite(msg.lat) || !Number.isFinite(msg.lng)) return;
  const p = project(world.origin, { lat: msg.lat, lng: msg.lng });
  const accuracy = Number.isFinite(msg.accuracy) ? Math.max(0, msg.accuracy) : self.gpsAccuracy;
  const cur = self.moveTarget;
  if (cur) {
    // JITTER GUARDS (field-tested on real walks): once a position is established,
    //  • a fix WORSE than GPS_REJECT_ACC_M is dropped — a canopy/indoor accuracy spike
    //    must never yank the pawn (accuracy still updates so the client can show "blurry");
    //  • a fix within GPS_DEADBAND_M of the current target only refreshes accuracy —
    //    a standing player stops shimmering around their own position.
    if (accuracy > GPS_REJECT_ACC_M) {
      self.gpsAccuracy = accuracy;
      self.updatedAt = now;
      return;
    }
    if (Math.hypot(p.x - cur.x, p.y - cur.y) <= GPS_DEADBAND_M) {
      self.gpsAccuracy = accuracy;
      self.updatedAt = now;
      return;
    }
  }
  // TELEPORT, don't trudge: the FIRST fix of a session (target cleared on join/resume)
  // or a jump too big to be a walk (drove across town, reopened the app) snaps the pawn
  // straight to the fix. Easing the whole way would paint a bogus hex-trail of claimed
  // territory between the two locations. A bad-accuracy spike can't reach here past the
  // reject guard, so only real relocations snap.
  if (!cur || Math.hypot(p.x - self.pos.x, p.y - self.pos.y) > GPS_TELEPORT_M) {
    self.pos.x = p.x;
    self.pos.y = p.y;
  }
  self.moveTarget = { x: p.x, y: p.y };
  self.gpsAccuracy = accuracy;
  self.updatedAt = now;
}

/**
 * stepMovement — advance every online player toward its GPS target one fixed tick.
 * Exponential smoothing (MOVE_SMOOTH_ALPHA) gives soft approach; the per-tick step
 * length is clamped to MOVE_MAX_MPS · dt so a jumpy fix can't teleport the avatar.
 * Bumps updatedAt only when the position actually changes, so the delta broadcaster
 * can cheaply tell movers from the still. Deterministic: no clock reads, no RNG.
 */
export function stepMovement(world: World, dtMs: number, now: number): void {
  const dt = dtMs / 1000;
  const maxStep = MOVE_MAX_MPS * dt;
  for (const p of world.players.values()) {
    if (p.lifeState !== 'alive') continue; // a downed player lies where they fell until revive/respawn
    const target = p.moveTarget;
    if (!target) continue;

    const dx = target.x - p.pos.x;
    const dy = target.y - p.pos.y;
    const remaining = Math.hypot(dx, dy);
    if (remaining <= MOVE_ARRIVE_EPS) continue;

    let sx = dx * MOVE_SMOOTH_ALPHA;
    let sy = dy * MOVE_SMOOTH_ALPHA;
    const stepLen = Math.hypot(sx, sy);
    if (stepLen > maxStep) {
      const k = maxStep / stepLen;
      sx *= k;
      sy *= k;
    }
    p.pos.x += sx;
    p.pos.y += sy;
    p.updatedAt = now;
  }
}

/**
 * Drop a player's move target so the NEXT fix teleports ("first fix of the session"
 * snap). Called on join/resume: reopening the app plants you at your real position,
 * never walking the pawn from a stale persisted spot across the map (and claiming a
 * hex-trail on the way).
 */
export function clearMoveTarget(p: Player): void {
  p.moveTarget = null;
}

/** §14 driving guard: claiming (and combat, enforced by the combat system) pauses
 * above SPEED_PAUSE_KMH while the safety setting is on. */
export function isSpeedPaused(p: Player): boolean {
  return p.settings.speedPause && p.speedKmh > SPEED_PAUSE_KMH;
}
