// Movement guards (DESIGN §GPS): a fix is a move target, never a teleport — except
// the first fix of a session and genuine relocations, which snap.

import { describe, expect, it } from 'vitest';
import { SimHarness } from '../harness/sim-harness.js';
import { isSpeedPaused } from '../../sim/systems/movement.js';
import { GPS_REJECT_ACC_M, MOVE_MAX_MPS, TICK_MS } from '../../shared/constants.js';
import { SPEED_PAUSE_KMH } from '../../shared/tuning.js';

function setup() {
  const h = SimHarness.create({ seed: 'move-test' });
  const { player, conn } = h.join('walker');
  return { h, player, conn };
}

describe('movement', () => {
  it('first fix of a session snaps the pawn (no easing, no hex-trail)', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 100, y: 50 });
    expect(player.pos.x).toBeCloseTo(100, 4);
    expect(player.pos.y).toBeCloseTo(50, 4);
    expect(player.moveTarget).not.toBeNull();
  });

  it('first fix is accepted even with poor accuracy (no position yet beats none)', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 40, y: 0 }, { accuracy: GPS_REJECT_ACC_M + 30 });
    expect(player.pos.x).toBeCloseTo(40, 4);
  });

  it('established: accuracy worse than 50 m is rejected (accuracy still reported)', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 100, y: 50 });
    h.gpsAt(conn, { x: 130, y: 50 }, { accuracy: 80 });
    expect(player.moveTarget!.x).toBeCloseTo(100, 4);
    expect(player.gpsAccuracy).toBe(80);
  });

  it('established: sub-2.5 m deadband only refreshes accuracy', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 100, y: 50 });
    h.gpsAt(conn, { x: 101, y: 50 }, { accuracy: 9 });
    expect(player.moveTarget!.x).toBeCloseTo(100, 4);
    expect(player.gpsAccuracy).toBe(9);
  });

  it('walk-range fixes ease at most MOVE_MAX_MPS per second, then arrive', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 100, y: 50 });
    h.gpsAt(conn, { x: 130, y: 50 });
    expect(player.pos.x).toBeCloseTo(100, 4); // no teleport on a 30 m fix
    h.tick(1);
    const stepped = player.pos.x - 100;
    expect(stepped).toBeGreaterThan(0);
    expect(stepped).toBeLessThanOrEqual(MOVE_MAX_MPS * (TICK_MS / 1000) + 1e-9);
    h.tick(300);
    expect(player.pos.x).toBeCloseTo(130, 0);
  });

  it('a >60 m jump on a good fix is a genuine relocation: snap', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 100, y: 50 });
    h.gpsAt(conn, { x: 300, y: 50 }, { accuracy: 10 });
    expect(player.pos.x).toBeCloseTo(300, 4);
  });

  it('speed-pause flag: over 15 km/h with the safety setting on', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 0, y: 0 }, { speedKmh: SPEED_PAUSE_KMH + 5 });
    expect(isSpeedPaused(player)).toBe(true);
    h.gpsAt(conn, { x: 0, y: 0 }, { speedKmh: 5 });
    expect(isSpeedPaused(player)).toBe(false);
    player.settings.speedPause = false;
    h.gpsAt(conn, { x: 0, y: 0 }, { speedKmh: 99 });
    expect(isSpeedPaused(player)).toBe(false);
  });

  it('steps ride the GPS stream into stepsToday', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 0, y: 0 }, { steps: 1204 });
    expect(player.stepsToday).toBe(1204);
  });
});
