// app.ts — the Hono HTTP app + the Node http.Server it runs on. ONE server, ONE
// port: GET /healthz + GET /status here; the ws gateway attaches to the SAME
// server's 'upgrade' event for /ws. I/O edge (not sim; time via the injected clock).
//
// No @hono/node-server dependency: the tiny request-listener adapter bridging
// Node's IncomingMessage/ServerResponse to Hono's fetch(Request)→Response is
// ported from SideQuestAppV2 server/app.ts (static-file serving dropped — the
// YAS client is a Godot app, not a web bundle).

import { Hono } from 'hono';
import { createServer, type Server as HttpServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { Readable } from 'node:stream';
import type { World } from './shared/entities.js';
import type { Clock } from './sim/loop.js';

export interface AppDeps {
  world: World;
  clock: Clock;
  /** Boot stamp (clock time) for the /status uptime readout. */
  startedAt: number;
}

/** createApp — GET /healthz ('ok') + GET /status (ops JSON, no secrets: no seed,
 * no origin, no tokens). Everything else 404s. */
export function createApp(deps: AppDeps): Hono {
  const app = new Hono();

  app.get('/healthz', (c) => c.text('ok'));

  app.get('/status', (c) => {
    const { world, clock, startedAt } = deps;
    let playersOnline = 0;
    for (const p of world.players.values()) if (p.connId !== null) playersOnline += 1;
    let hexesOwned = 0;
    for (const hs of world.hexes.values()) if (hs.owner === 'players') hexesOwned += 1;
    return c.json({
      tick: world.tick,
      playersOnline,
      hexesOwned,
      frontsTouched: world.fronts.size,
      uptimeSec: Math.round((clock.now() - startedAt) / 1000),
    });
  });

  return app;
}

// ---------------------------------------------------------------------------
// Node http adapter — IncomingMessage/ServerResponse ⇄ Hono fetch(Request).
// ---------------------------------------------------------------------------

function toWebRequest(req: IncomingMessage): Request {
  const host = req.headers.host ?? 'localhost';
  const url = `http://${host}${req.url ?? '/'}`;
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) {
    if (v === undefined) continue;
    if (Array.isArray(v)) for (const x of v) headers.append(k, x);
    else headers.set(k, v);
  }
  const method = req.method ?? 'GET';
  const hasBody = method !== 'GET' && method !== 'HEAD';
  const init: RequestInit & { duplex?: 'half' } = { method, headers };
  if (hasBody) {
    init.body = Readable.toWeb(req) as unknown as ReadableStream;
    init.duplex = 'half';
  }
  return new Request(url, init);
}

async function sendWebResponse(res: ServerResponse, response: Response): Promise<void> {
  res.statusCode = response.status;
  response.headers.forEach((value, key) => res.setHeader(key, value));
  const buf = Buffer.from(await response.arrayBuffer());
  res.end(buf);
}

/**
 * createHttpServer(app) — a Node http.Server whose request listener runs the Hono
 * app. The ws gateway attaches to the returned server so HTTP and WS share a port.
 */
export function createHttpServer(app: Hono): HttpServer {
  return createServer((req, res) => {
    Promise.resolve(app.fetch(toWebRequest(req)))
      .then((response) => sendWebResponse(res, response))
      .catch((err: unknown) => {
        res.statusCode = 500;
        res.end(`internal error: ${String(err)}`);
      });
  });
}
