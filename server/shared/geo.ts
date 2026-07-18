// shared/geo.ts — meter-space helpers + the pure lat/lng ⇄ world-meter projection.
// I/O-free, deterministic. Used by the server (GPS ingestion) and later by codegen
// for the client. Ported from SideQuestAppV2 shared/geo.ts (geo-shard cell helpers
// dropped — v1 is a single world).
//
// Projection: equirectangular local-tangent-plane at `origin`. x = meters EAST,
// y = meters NORTH. Correct at neighbourhood scale; swappable later without touching
// sim or protocol code (the project/unproject contract is fixed).

import type { LatLng, Vec2 } from './entities.js';

/** Mean Earth radius in meters. */
export const EARTH_R = 6_371_000;
const DEG2RAD = Math.PI / 180;
const RAD2DEG = 180 / Math.PI;

/**
 * project(origin, {lat,lng}) → {x,y} meters (east, north) from origin.
 * Equirectangular around origin: longitude scaled by cos(originLat).
 */
export function project(origin: LatLng, p: LatLng): Vec2 {
  const x = (p.lng - origin.lng) * DEG2RAD * EARTH_R * Math.cos(origin.lat * DEG2RAD);
  const y = (p.lat - origin.lat) * DEG2RAD * EARTH_R;
  return { x, y };
}

/** unproject(origin, {x,y}) → {lat,lng}. Exact inverse of project. */
export function unproject(origin: LatLng, v: Vec2): LatLng {
  const lat = origin.lat + (v.y / EARTH_R) * RAD2DEG;
  const lng = origin.lng + (v.x / (EARTH_R * Math.cos(origin.lat * DEG2RAD))) * RAD2DEG;
  return { lat, lng };
}

/** Euclidean distance in meters between two world points. */
export function distM(a: Vec2, b: Vec2): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

/** Squared distance (cheaper for comparisons). */
export function dist2(a: Vec2, b: Vec2): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
}

/** True if `a` is within `r` meters of `b`. */
export function within(a: Vec2, b: Vec2, r: number): boolean {
  return dist2(a, b) <= r * r;
}

/** Clamp a scalar to [lo, hi]. */
export function clamp(n: number, lo: number, hi: number): number {
  return n < lo ? lo : n > hi ? hi : n;
}

/**
 * haversine great-circle distance (meters) between two lat/lng points.
 * Reference/validation helper; sim distance uses meter-space `distM`.
 */
export function haversine(a: LatLng, b: LatLng): number {
  const dLat = (b.lat - a.lat) * DEG2RAD;
  const dLng = (b.lng - a.lng) * DEG2RAD;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * DEG2RAD) * Math.cos(b.lat * DEG2RAD) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_R * Math.asin(Math.min(1, Math.sqrt(s)));
}
