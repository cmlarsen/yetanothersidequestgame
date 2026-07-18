// The ONE real-socket test (everything else drives applyCommand in-process): a
// real http server + ws gateway on an ephemeral port proving the edge end-to-end —
// upgrade on WS_PATH only, JOIN → [HELLO, SNAPSHOT, INVENTORY_UPDATE], the
// server-initiated PING/PONG heartbeat (PONG keeps you alive, silence terminates
// after MISSED_PONGS_LIMIT), (j) malformed frames costing one ERR BAD_REQUEST and
// never the socket, and the version gate closing 4400 after its ERR frame.

import { afterEach, describe, expect, it } from 'vitest';
import { WebSocket } from 'ws';
import type { AddressInfo } from 'node:net';
import type { Server as HttpServer } from 'node:http';
import { createApp, createHttpServer } from '../../app.js';
import { attachGateway, CLOSE_VERSION_MISMATCH, type Gateway } from '../../net/gateway.js';
import { createWorld } from '../../sim/world.js';
import { MISSED_PONGS_LIMIT, WS_PATH } from '../../shared/constants.js';
import { OP, PROTOCOL_VERSION, encode } from '../../shared/protocol.js';
import type { ClientMsg, ErrMsg, HelloMsg, ServerMsg } from '../../shared/protocol.js';
import '../../sim/commands_combat.js';
import '../../sim/commands_economy.js';

interface Rig {
  port: number;
  http: HttpServer;
  gateway: Gateway;
}

const rigs: Rig[] = [];
const sockets: WebSocket[] = [];

async function startRig(heartbeatMs = 60_000): Promise<Rig> {
  const world = createWorld('gateway-int', { lat: 40.2338, lng: -111.6585 }, 0);
  const clock = { now: () => Date.now() };
  const http = createHttpServer(createApp({ world, clock, startedAt: clock.now() }));
  const gateway = attachGateway(http, world, { clock, tickHz: 10, heartbeatMs });
  await new Promise<void>((resolve) => http.listen(0, resolve));
  const rig = { port: (http.address() as AddressInfo).port, http, gateway };
  rigs.push(rig);
  return rig;
}

afterEach(async () => {
  for (const ws of sockets.splice(0)) ws.terminate();
  for (const rig of rigs.splice(0)) {
    rig.gateway.close();
    await new Promise<void>((resolve) => rig.http.close(() => resolve()));
  }
});

/** A ws client with an inbox: awaits frames matching a predicate, records close. */
class Client {
  readonly inbox: ServerMsg[] = [];
  closeCode: number | null = null;
  private waiters: Array<{ pred: (m: ServerMsg) => boolean; resolve: (m: ServerMsg) => void }> = [];
  private closeWaiters: Array<(code: number) => void> = [];

  private constructor(readonly ws: WebSocket) {}

  static connect(port: number, path = WS_PATH): Promise<Client> {
    const ws = new WebSocket(`ws://127.0.0.1:${port}${path}`);
    sockets.push(ws);
    const client = new Client(ws);
    ws.on('message', (data: Buffer) => {
      const msg = JSON.parse(data.toString()) as ServerMsg;
      const i = client.waiters.findIndex((w) => w.pred(msg));
      if (i >= 0) client.waiters.splice(i, 1)[0].resolve(msg);
      else client.inbox.push(msg);
    });
    ws.on('close', (code: number) => {
      client.closeCode = code;
      for (const w of client.closeWaiters.splice(0)) w(code);
    });
    return new Promise((resolve, reject) => {
      ws.on('open', () => resolve(client));
      ws.on('error', (err: Error) => reject(err));
    });
  }

  send(msg: ClientMsg): void {
    this.ws.send(encode(msg));
  }

  /** Next frame matching `pred` (inbox first), or reject after `timeoutMs`. */
  next(pred: (m: ServerMsg) => boolean, timeoutMs = 3000): Promise<ServerMsg> {
    const i = this.inbox.findIndex(pred);
    if (i >= 0) return Promise.resolve(this.inbox.splice(i, 1)[0]);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('timed out waiting for frame')), timeoutMs);
      this.waiters.push({
        pred,
        resolve: (m) => {
          clearTimeout(timer);
          resolve(m);
        },
      });
    });
  }

  closed(timeoutMs = 3000): Promise<number> {
    if (this.closeCode !== null) return Promise.resolve(this.closeCode);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('timed out waiting for close')), timeoutMs);
      this.closeWaiters.push((code) => {
        clearTimeout(timer);
        resolve(code);
      });
    });
  }
}

function join(c: Client, gamertag: string): void {
  c.send({
    op: OP.JOIN,
    t: Date.now(),
    protocolVersion: PROTOCOL_VERSION,
    gamertag,
    characterId: 'knight',
  });
}

describe('ws gateway on an ephemeral port', () => {
  it('upgrades on WS_PATH and JOIN replies HELLO, SNAPSHOT, INVENTORY_UPDATE in order', async () => {
    const rig = await startRig();
    const c = await Client.connect(rig.port);
    join(c, 'edgewalker');
    const hello = (await c.next((m) => m.op === OP.HELLO)) as HelloMsg;
    expect(hello.protocolVersion).toBe(PROTOCOL_VERSION);
    expect(hello.playerId).not.toBe('');
    expect(hello.sessionToken).not.toBe('');
    // burst order: SNAPSHOT then INVENTORY_UPDATE arrived behind HELLO
    await c.next((m) => m.op === OP.SNAPSHOT);
    await c.next((m) => m.op === OP.INVENTORY_UPDATE);
    expect(c.inbox).toEqual([]);
  });

  it('destroys upgrades on any other path', async () => {
    const rig = await startRig();
    await expect(Client.connect(rig.port, '/nope')).rejects.toThrow();
  });

  it('heartbeat: PONG keeps the socket alive; silence terminates it', async () => {
    const rig = await startRig(60);
    const quiet = await Client.connect(rig.port);
    const lively = await Client.connect(rig.port);
    lively.ws.on('message', (data: Buffer) => {
      const msg = JSON.parse(data.toString()) as ServerMsg;
      if (msg.op === OP.PING) lively.send({ op: OP.PONG, t: Date.now() });
    });

    // the silent socket dies after MISSED_PONGS_LIMIT unanswered intervals
    await expect(quiet.closed()).resolves.toBeDefined();
    // the ponging socket outlived it by multiple heartbeat cycles
    for (let i = 0; i < MISSED_PONGS_LIMIT + 2; i++) {
      await lively.next((m) => m.op === OP.PING);
    }
    expect(lively.closeCode).toBeNull();
  });

  it('(j) a malformed frame costs one ERR BAD_REQUEST, never the socket', async () => {
    const rig = await startRig();
    const c = await Client.connect(rig.port);

    c.ws.send('definitely not json');
    const err1 = (await c.next((m) => m.op === OP.ERR)) as ErrMsg;
    expect(err1.code).toBe('BAD_REQUEST');

    c.ws.send(JSON.stringify({ op: 9999, t: 1 })); // unknown op fails the zod codec
    const err2 = (await c.next((m) => m.op === OP.ERR)) as ErrMsg;
    expect(err2.code).toBe('BAD_REQUEST');

    // the socket survived both and still serves intents
    join(c, 'survivor');
    await c.next((m) => m.op === OP.HELLO);
  });

  it('(j) JOIN with a wrong protocolVersion: ERR VERSION_MISMATCH then close 4400', async () => {
    const rig = await startRig();
    const c = await Client.connect(rig.port);
    c.send({
      op: OP.JOIN,
      t: Date.now(),
      protocolVersion: PROTOCOL_VERSION + 1,
      gamertag: 'futureclient',
      characterId: 'knight',
    });
    const err = (await c.next((m) => m.op === OP.ERR)) as ErrMsg;
    expect(err.code).toBe('VERSION_MISMATCH');
    await expect(c.closed()).resolves.toBe(CLOSE_VERSION_MISMATCH);
  });
});
