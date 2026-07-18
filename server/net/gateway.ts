// net/gateway.ts — the WebSocket edge. Attaches ws.Server({noServer:true}) to the
// SHARED http.Server and accepts upgrades on WS_PATH. Decodes frames through the
// shared/protocol zod codec (a parse failure costs one ERR frame, never a crash),
// routes every intent through the single applyCommand reducer, enforces
// protocolVersion on JOIN/RESUME (mismatch → ERR VERSION_MISMATCH + close 4400),
// runs the server-initiated heartbeat, and drives the two-lane outbound pump each
// tick. I/O edge: real sockets, real ids — NOT the sim (time still arrives via the
// injected clock). Ported from SideQuestAppV2 server/net/gateway.ts (WorldManager
// dropped — v1 is a single world; version enforcement added).

import { WebSocketServer, WebSocket } from 'ws';
import { randomUUID } from 'node:crypto';
import type { Server as HttpServer, IncomingMessage } from 'node:http';
import type { Duplex } from 'node:stream';
import type { World } from '../shared/entities.js';
import type { ClientMsg, ServerMsg } from '../shared/protocol.js';
import { OP, PROTOCOL_VERSION, decodeClient, encode } from '../shared/protocol.js';
import { seededRng } from '../shared/rng.js';
import { HEARTBEAT_MS, MISSED_PONGS_LIMIT, WS_PATH } from '../shared/constants.js';
import { applyCommand, type CommandCtx, type Conn as SimConn } from '../sim/commands.js';
import type { Clock } from '../sim/loop.js';
import { newInterest, pumpOutbound, type Interest } from './outbound.js';

/** Application close code for a protocol-version mismatch (4000-4999 = app range). */
export const CLOSE_VERSION_MISMATCH = 4400;

export interface GatewayOpts {
  clock: Clock;
  tickHz: number;
  /** Server ping cadence (ms). Tests inject a small value; prod uses HEARTBEAT_MS. */
  heartbeatMs?: number;
}

export interface Gateway {
  /** Called by the loop each tick — drains the outbox + broadcasts DELTAs. */
  onTick(world: World, tick: number, now: number): void;
  /** Send an already-built frame to one connection. */
  sendTo(connId: string, msg: ServerMsg): void;
  /** Stop heartbeat + close all sockets (SIGTERM path). */
  close(): void;
}

/** The gateway's per-socket record: the sim's binding record + socket bookkeeping. */
interface Conn extends SimConn {
  socket: WebSocket;
  missedPongs: number;
  seqCursor: number;
  interest: Interest;
}

/**
 * attachGateway — wire the ws server onto `http`. Upgrades on WS_PATH become
 * connections; every decoded frame routes through applyCommand with a per-command
 * ctx {now, rng: seededRng(seed, connId, tick, seq), genId, tickHz}. A closed
 * socket only clears the player's connId — the player goes offline, resumable.
 */
export function attachGateway(http: HttpServer, world: World, opts: GatewayOpts): Gateway {
  const wss = new WebSocketServer({ noServer: true });
  const conns = new Map<string, Conn>();

  http.on('upgrade', (req: IncomingMessage, socket: Duplex, head: Buffer) => {
    const url = new URL(req.url ?? '/', 'http://localhost');
    if (url.pathname !== WS_PATH) {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => onConnect(ws));
  });

  function onConnect(ws: WebSocket): void {
    const conn: Conn = {
      connId: randomUUID(),
      playerId: null,
      sessionToken: '',
      socket: ws,
      missedPongs: 0,
      seqCursor: 0,
      interest: newInterest(),
    };
    conns.set(conn.connId, conn);
    ws.on('message', (data: Buffer) => onMessage(conn, data.toString()));
    ws.on('close', () => onClose(conn));
    ws.on('error', () => onClose(conn));
  }

  function onMessage(conn: Conn, raw: string): void {
    const now = opts.clock.now();
    let msg: ClientMsg;
    try {
      msg = decodeClient(raw);
    } catch {
      send(conn, { op: OP.ERR, t: now, code: 'BAD_REQUEST', message: 'undecodable frame' });
      return;
    }

    // Heartbeat reply — edge bookkeeping, never enters the reducer.
    if (msg.op === OP.PONG) {
      conn.missedPongs = 0;
      return;
    }

    // Version gate (DESIGN: V2 declared but never checked it). The ERR frame tells
    // the client why; the app-range close code makes it terminal, not retryable.
    if ((msg.op === OP.JOIN || msg.op === OP.RESUME) && msg.protocolVersion !== PROTOCOL_VERSION) {
      send(conn, {
        op: OP.ERR,
        t: now,
        code: 'VERSION_MISMATCH',
        message: `server speaks protocol v${PROTOCOL_VERSION}`,
        refOp: msg.op,
      });
      conn.socket.close(CLOSE_VERSION_MISMATCH, 'protocol version mismatch');
      return;
    }

    // A monotonic per-socket seq orders intents (client-sent when present).
    const seq = typeof msg.seq === 'number' ? msg.seq : ++conn.seqCursor;
    const ctx: CommandCtx = {
      now,
      rng: seededRng(world.seed, conn.connId, world.tick, seq),
      conn,
      tickHz: opts.tickHz,
      genId: (kind) => `${kind}_${randomUUID()}`,
    };
    for (const reply of applyCommand(world, msg, ctx)) send(conn, reply);
  }

  function onClose(conn: Conn): void {
    conns.delete(conn.connId);
    const player = conn.playerId !== null ? world.players.get(conn.playerId) : undefined;
    if (player && player.connId === conn.connId) player.connId = null; // offline, resumable
  }

  function send(conn: Conn, msg: ServerMsg): void {
    if (conn.socket.readyState === WebSocket.OPEN) conn.socket.send(encode(msg));
  }

  // Server-initiated heartbeat: PING every heartbeatMs, terminate after
  // MISSED_PONGS_LIMIT intervals without a PONG.
  const heartbeat = setInterval(() => {
    const now = opts.clock.now();
    for (const conn of conns.values()) {
      if (conn.missedPongs >= MISSED_PONGS_LIMIT) {
        conn.socket.terminate();
        onClose(conn);
        continue;
      }
      conn.missedPongs += 1;
      send(conn, { op: OP.PING, t: now, tServer: now });
    }
  }, opts.heartbeatMs ?? HEARTBEAT_MS);

  return {
    onTick(w, tick, now) {
      pumpOutbound(w, conns.values(), tick, now, (connId, msg) => {
        const conn = conns.get(connId);
        if (conn) send(conn, msg);
      });
    },
    sendTo(connId, msg) {
      const conn = conns.get(connId);
      if (conn) send(conn, msg);
    },
    close() {
      clearInterval(heartbeat);
      for (const conn of conns.values()) conn.socket.terminate();
      conns.clear();
      wss.close();
    },
  };
}
