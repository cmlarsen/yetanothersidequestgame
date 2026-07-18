// test/harness/manual-clock.ts — the deterministic clock the harness injects into
// sim/loop.ts. Satisfies the loop's Clock interface but time only moves when a test
// calls advance()/advanceTicks(): "now" is a value the test owns, so the same seed +
// same advances give a bit-identical world. Ported from SideQuestAppV2
// test/harness/clock.ts.

import { TICK_MS } from '../../shared/constants.js';
import type { Clock } from '../../sim/loop.js';

export class ManualClock implements Clock {
  private ms: number;
  private t: number;

  constructor(startMs = 0) {
    this.ms = startMs;
    this.t = 0;
  }

  /** Current injected wall time (ms). Never reads a real clock. */
  now(): number {
    return this.ms;
  }

  /** The manual tick counter (distinct from world.tick; a convenience for tests). */
  tick(): number {
    return this.t;
  }

  /** Move wall time forward by `ms` (does not, by itself, run the sim loop). */
  advance(ms: number): void {
    this.ms += ms;
  }

  /** Move time forward by `n` ticks of `tickMs` each, bumping the tick counter. */
  advanceTicks(n: number, tickMs: number = TICK_MS): void {
    for (let i = 0; i < n; i++) {
      this.ms += tickMs;
      this.t += 1;
    }
  }
}
