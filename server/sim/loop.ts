// sim/loop.ts — fixed-timestep driver. Clock-injected: the loop NEVER reads a wall
// clock itself; `clock.now()` supplies time (system clock in prod, ManualClock in
// tests). Correctness comes from the accumulator — the interval in start() is a
// scheduling nudge only. Ported from SideQuestAppV2 server/sim/loop.ts (the F4b
// multi-world provider is dropped: v1 is a single world; the seam survives because
// everything takes `world`).

import type { World } from '../shared/entities.js';
import { tickWorld } from './world.js';

/** The only source of "now" for the loop (ManualClock in tests, system clock in prod). */
export interface Clock {
  now(): number;
}

export interface LoopOpts {
  world: World;
  tickHz: number;
  clock: Clock;
  /** Called after each fixed tick advances — the gateway broadcasts from here. */
  onTick?: (world: World, tick: number, now: number) => void;
}

export interface Loop {
  /** Advance the sim to catch up to clock.now() using a fixed-step accumulator. Returns ticks run. */
  pump(): number;
  /** Force exactly one fixed tick (used by tests / manual stepping). Returns the new tick. */
  step(): number;
  /** Begin driving from a real timer (prod). No-op if already running. */
  start(): void;
  /** Stop the timer. Safe to call when not running. */
  stop(): void;
  running(): boolean;
}

/** Cap on catch-up ticks per pump (e.g. after a debugger pause); past it the backlog is dropped. */
export const MAX_BURST = 100;

export function createLoop(opts: LoopOpts): Loop {
  const { world, clock, onTick } = opts;
  const tickMs = 1000 / opts.tickHz;
  let last = clock.now();
  let acc = 0;
  let timer: ReturnType<typeof setInterval> | null = null;

  function step(): number {
    const now = clock.now();
    tickWorld(world, tickMs, now);
    onTick?.(world, world.tick, now);
    return world.tick;
  }

  function pump(): number {
    const now = clock.now();
    acc += now - last;
    last = now;
    let ran = 0;
    while (acc >= tickMs && ran < MAX_BURST) {
      acc -= tickMs;
      step();
      ran++;
    }
    if (ran >= MAX_BURST) acc = 0;
    return ran;
  }

  return {
    pump,
    step,
    start() {
      if (timer) return;
      last = clock.now();
      acc = 0;
      timer = setInterval(pump, tickMs);
    },
    stop() {
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
    },
    running() {
      return timer !== null;
    },
  };
}
