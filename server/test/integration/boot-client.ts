// boot-client.ts — MANUAL boot-proof probe (not a vitest file): a minimal ws
// client for a locally running server. JOIN → HELLO/SNAPSHOT → RUN_START + GPS at
// the world origin → exits 0 the moment a hex-claim beat arrives (EVENTS) —
// proving the full socket → reducer → tick → outbox → broadcast path live.
//
//   PORT=8399 npm start &          # temp DATA_DIR recommended
//   PORT=8399 npx tsx test/integration/boot-client.ts

import { WebSocket } from 'ws';
import { OP, PROTOCOL_VERSION } from '../../shared/protocol.js';
import type { ServerMsg } from '../../shared/protocol.js';

const port = process.env.PORT ?? '8080';
const lat = Number(process.env.ORIGIN_LAT ?? 37.7749);
const lng = Number(process.env.ORIGIN_LNG ?? -122.4194);

const ws = new WebSocket(process.env.WS_URL ?? `ws://127.0.0.1:${port}/ws`);
const t = (): number => Date.now();
const send = (msg: object): void => ws.send(JSON.stringify(msg));

const deadline = setTimeout(() => {
  console.error('[client] TIMEOUT: no claim seen within 15 s');
  process.exit(1);
}, 15_000);

let snapshotSeen = false;

ws.on('open', () => {
  console.log('[client] connected — sending JOIN');
  send({
    op: OP.JOIN,
    t: t(),
    protocolVersion: PROTOCOL_VERSION,
    gamertag: 'bootproof',
    characterId: 'knight',
  });
});

ws.on('message', (data: Buffer) => {
  const m = JSON.parse(data.toString()) as ServerMsg;
  switch (m.op) {
    case OP.HELLO:
      console.log(`[client] HELLO player=${m.playerId} tickHz=${m.tickHz} hexAcrossM=${m.hexAcrossM}`);
      break;
    case OP.SNAPSHOT:
      if (snapshotSeen) break;
      snapshotSeen = true;
      console.log(`[client] SNAPSHOT tick=${m.tick} hexes=${m.hexes.length} fronts=${m.fronts.length}`);
      send({ op: OP.RUN_START, t: t() });
      send({ op: OP.GPS, t: t(), lat, lng, accuracy: 5 });
      console.log('[client] sent RUN_START + GPS at world origin');
      break;
    case OP.PING:
      send({ op: OP.PONG, t: t() });
      break;
    case OP.DELTA:
      if (m.upserts.hexes?.length) {
        console.log(`[client] DELTA hex upsert: ${JSON.stringify(m.upserts.hexes)}`);
      }
      break;
    case OP.EVENTS:
      for (const ev of m.events) {
        console.log(`[client] EVENT ${JSON.stringify(ev)}`);
        if (ev.k === 'claim') {
          console.log(`[client] CLAIM CONFIRMED hex=${ev.hexKey} owner=${ev.o} front=${ev.frontId}`);
          clearTimeout(deadline);
          ws.close();
          process.exit(0);
        }
      }
      break;
    default:
      break;
  }
});

ws.on('error', (err: Error) => {
  console.error('[client] socket error:', err.message);
  process.exit(1);
});
