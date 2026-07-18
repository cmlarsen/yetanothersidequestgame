// shared/constants.ts — structural net/loop constants (tick rate, radii, GPS guards).
// NOT balance numbers (those live in tuning.ts). I/O-free, deterministic.
// GPS/movement guard values carried from SideQuestAppV2 shared/constants.ts
// (field-tested on real walks); the rest per server/DESIGN.md.

// ---- tick / broadcast ----
export const TICK_HZ = 10;
export const TICK_MS = 1000 / TICK_HZ; // 100 ms
export const BROADCAST_EVERY_TICKS = 2; // positional DELTAs at 5 Hz; outbox events drain every tick

// ---- heartbeat ----
export const HEARTBEAT_MS = 10_000; // server-initiated PING cadence
export const MISSED_PONGS_LIMIT = 2; // terminate after 2 missed PONGs

// ---- interest / relevance ----
// Per-connection delta window: a walking session's whole neighbourhood (a few fronts
// of 8×8 60 m hexes) fits inside this radius; farther entities never ride your wire.
export const RELEVANCE_M = 1200;

// ---- gateway ----
export const WS_PATH = '/ws';

// ---- fronts (DESIGN §fronts): static seed-derived partition into 8×8-hex super-cells ----
export const FRONT_CELL_HEXES = 8; // front = one super-cell; size = 8×8 = 64 hexes

// ---- GPS ingestion (a fix is a MOVE TARGET, never a teleport) ----
export const GPS_MAX_HZ = 4; // client-side send throttle; server rate-tolerates
export const GPS_REJECT_ACC_M = 50; // drop established-player fixes with accuracy worse than this
export const GPS_DEADBAND_M = 2.5; // ignore sub-deadband target moves (standing-still jitter)
// A jump larger than this from a GOOD-accuracy fix is a genuine relocation (drive/reopen):
// snap instead of trudging (and never paint a hex-trail across it). Sits above the
// accuracy-reject ceiling so accepted jitter can never snap.
export const GPS_TELEPORT_M = 60;

// ---- movement smoothing (the per-tick clamp between GPS target and pawn) ----
export const MOVE_MAX_MPS = 4; // brisk-walk/jog cap; canopy drift never teleports the pawn
export const MOVE_SMOOTH_ALPHA = 0.3; // per-tick easing toward the GPS target (0..1)
export const MOVE_ARRIVE_EPS = 0.05; // m — closer than this counts as "arrived"
