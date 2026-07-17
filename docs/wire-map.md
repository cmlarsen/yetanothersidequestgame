# Wire map — the one §3 vocabulary (M0 FROZEN)

Authority for downstream milestones (§11.1). Every §4–§9 message **name** is an alias to a
single §3 `OP` enum member in `shared/protocol.ts`. **No new opcode exists until it is added
to §3.2/§3.3 and this table.** Reconciliation is a mechanical rename pass, not a redesign.

The §3 reconciliation edits (§11.6 turn-model, §11.14 intent-ordering + `sid`, §11.16
auto/walking timing) are folded into `shared/protocol.ts` and noted below.

## Opcode registry (§3.2 client→server, §3.3 server→client)

| OP | # | Dir | Payload type (`protocol.ts`) | Payload shape (post-reconciliation) |
|---|---|---|---|---|
| `JOIN` | 1 | C→S | `JoinMsg` | `{ name, classId, seq? }` |
| `RESUME` | 2 | C→S | `ResumeMsg` | `{ sessionToken, seq? }` |
| `GPS` | 3 | C→S | `GpsMsg` | `{ lat, lng, accuracy, seq? }` |
| `MOVE` | 4 | C→S | `MoveMsg` | `{ x, y, seq? }` (debug/no-GPS) |
| `ENGAGE` | 5 | C→S | `EngageMsg` | `{ breachId, seq? }` |
| `FLEE` | 6 | C→S | `FleeMsg` | `{ encounterId, seq? }` |
| `ATTACK` | 7 | C→S | `AttackMsg` | `{ encounterId, targetId, timing?: 0..1\|"auto"\|null, seq? }` — §11.16 |
| `USE_ABILITY` | 8 | C→S | `UseAbilityMsg` | `{ encounterId, abilityId, targetId, timing?: 0..1\|"auto"\|null, seq? }` — §11.16 |
| `GUARD` | 9 | C→S | `GuardMsg` | `{ encounterId, timing?, seq? }` |
| `LOOT` | 10 | C→S | `LootMsg` | `{ sourceId, seq? }` |
| `SEAL_BREACH` | 11 | C→S | `SealBreachMsg` | `{ breachId, seq? }` |
| `CAMP_ACTION` | 12 | C→S | `CampActionMsg` | `{ action:"place"\|"upgrade"\|"craft"\|"placeStructure", …, seq? }` |
| `MERCHANT` | 13 | C→S | `MerchantMsg` | `{ poiId, action:"buy"\|"sell", itemId?, defId?, qty, seq? }` |
| `INTERACT` | 14 | C→S | `InteractMsg` | `{ poiId, choiceId?, seq? }` |
| `EQUIP` | 15 | C→S | `EquipMsg` | `{ itemId, slot, equip, seq? }` |
| `REQUEST_SNAPSHOT` | 16 | C→S | `RequestSnapshotMsg` | `{ seq? }` |
| `PONG` | 17 | C→S | `PongMsg` | `{ seq? }` |
| `HELLO` | 100 | S→C | `HelloMsg` | `{ protocolVersion, characterId, sessionToken, origin, seed, tickHz, self }` |
| `SNAPSHOT` | 101 | S→C | `SnapshotMsg` | `{ tick, self, players, breaches, monsters, pois, camp, projectiles, party, convergence }` |
| `DELTA` | 102 | S→C | `DeltaMsg` | `{ tick, upserts{players?,monsters?,breaches?,projectiles?,camp?}, removes{kind:id[]} }` |
| `PLAYER_MOVED` | 103 | S→C | `PlayerMovedMsg` | `{ id, x, y, accuracy, tServer }` (may fold into `delta.upserts.players`) |
| `ENCOUNTER_OPEN` | 104 | S→C | `EncounterOpenMsg` | `{ encounterId, breachId, combatants, round, phase, deadlineMs, order }` — §11.6 |
| `ENCOUNTER_UPDATE` | 105 | S→C | `EncounterUpdateMsg` | `{ encounterId, events, combatants, round, phase, deadlineMs, focusMeter }` — §11.6 |
| `ENCOUNTER_END` | 106 | S→C | `EncounterEndMsg` | `{ encounterId, result:"win"\|"flee"\|"downed", loot, xpGained, levelUp? }` |
| `LOOT_RESULT` | 107 | S→C | `LootResultMsg` | `{ sourceId, items, gold }` |
| `BREACH_UPDATE` | 108 | S→C | `BreachUpdateMsg` | `{ breachId, state, hp, tier, sealedBy?, territoryId? }` |
| `CAMP_UPDATE` | 109 | S→C | `CampUpdateMsg` | `{ camp, territory? }` |
| `MERCHANT_RESULT` | 110 | S→C | `MerchantResultMsg` | `{ poiId, gold, inventory, stock }` |
| `DIALOGUE` | 111 | S→C | `DialogueMsg` | `{ poiId, speaker, lines, choices[{id,text}], kind?, portrait?, ranged?, pry? }` — M9 additive optional fields |
| `INVENTORY_UPDATE` | 112 | S→C | `InventoryUpdateMsg` | `{ inventory, equipment, stats, maxHp }` |
| `PARTY_UPDATE` | 113 | S→C | `PartyUpdateMsg` | `{ party, members[{id,name,classId,pos,hp,level}] }` |
| `ERR` | 114 | S→C | `ErrMsg` | `{ code, message, refOp? }` codes: SESSION_UNKNOWN, OUT_OF_RANGE, NOT_YOUR_TURN, BAD_REQUEST, INSUFFICIENT_GOLD, ILLEGAL_STATE |
| `PING` | 115 | S→C | `PingMsg` | `{ tServer }` |

## §4–§9 alias → §3 opcode (the rename pass, §11.1)

Every alias below **must** be rewritten to the OP member before any handler is built.

| Source | Alias name | → OP | Notes |
|---|---|---|---|
| §4 | `EncounterStart` | `ENCOUNTER_OPEN` (104) | §4 round-model payload (§11.6) |
| §4 | `TurnBegin` | `ENCOUNTER_UPDATE` (105) | now a `phase` transition, not a turn flip |
| §4 | `ActionSubmit` | `ATTACK` (7) / `USE_ABILITY` (8) / `GUARD` (9) | which op depends on action kind |
| §4 | `ActionResolved` | `ENCOUNTER_UPDATE` (105) | carries `CombatEvent[]` |
| §4 | `EncounterEnd` | `ENCOUNTER_END` (106) | |
| §6 | `world.snapshot` | `SNAPSHOT` (101) | |
| §6 | `breach.seal` | `SEAL_BREACH` (11) C→S; `BREACH_UPDATE` (108) S→C | intent vs result |
| §6 | `geo.fix` | `GPS` (3) | device fix → server projects to `{x,y}` |
| §7 | `bastion/place` | `CAMP_ACTION` (12) `action:"place"` | §11.7 Camp/Bastion split |
| §7 | `turret/build` | `CAMP_ACTION` (12) `action:"placeStructure"` | structure type `turret` |
| §7 | `bastion` (upgrade) | `CAMP_ACTION` (12) `action:"upgrade"` | |
| §7 | `craft/enqueue` | `CAMP_ACTION` (12) `action:"craft"` | enqueue variant |
| §7 | `craft/collect` | `CAMP_ACTION` (12) `action:"craft"` | collect variant → result via `CAMP_UPDATE` (109) |
| §7 | `session/resume` | `RESUME` (2) | away-report settle rides `SNAPSHOT`/`CAMP_UPDATE` |
| §7 | `away/report` | `CAMP_UPDATE` (109) | while-you-were-away block |
| §8 | `session.welcome` | `HELLO` (100) | |
| §8 | `combat.start` | `ENCOUNTER_OPEN` (104) | |
| §8 | `combat.event` | `ENCOUNTER_UPDATE` (105) | |
| §8 | `merchant.open` | `INTERACT` (14) C→S; `MERCHANT_RESULT` (110)/`DIALOGUE` (111) S→C | opening a merchant POI |
| §2.9/§6.6 | POI/NPC/quest dialogue | `INTERACT` (14) C→S (`{poiId, choiceId?}`); `DIALOGUE` (111) S→C | M9 conversation machine (in-person + ranged/apprentice path) |
| §5.10 | trapped-chest pry | `INTERACT` (14) `choiceId:"pry"\|"take"\|"leave"` C→S; `DIALOGUE` (111) running state + `LOOT_RESULT` (107)/`INVENTORY_UPDATE` (112) on bank S→C | M9 push-your-luck; reuses existing ops (no opcode added) |
| §9 | `c:*` / `s:*` prefixes | (the matching OP above) | §9's prefix scheme is dropped; use the enum |

## Folded-in §3 reconciliation edits

- **§11.6 turn-model.** `turn:"player"|"enemy"` is **deleted**. `ENCOUNTER_OPEN` /
  `ENCOUNTER_UPDATE` carry `{ round:number, phase:"command"|"resolution"|"end", deadlineMs:number }`.
  The §1.8 test example asserts `phase === "command"` (there is no `player_turn` state).
- **§11.14 intent-ordering + `sid`.** `sid` = **session id = `Connection.connId`** (stable per
  socket, assigned server-side — never sent by the client). Inbound intents are **queued, not
  applied on arrival**; the sim drains the queue at each tick boundary and applies in total order
  **`(tick, sid, seq)`**. Client intents carry an optional monotonic `seq`. §3.4's "combat
  resolves immediately" is corrected to **"resolves at the next tick boundary."**
- **§2.9/§6.6/§5.10 M9 dialogue additions.** `DIALOGUE` (111) gains OPTIONAL fields (`kind`, `portrait`,
  `ranged`, `pry`) — additive, no new opcode (same pattern as `BREACH_UPDATE.escalation?`). `INTERACT` (14)
  drives NPC/quest conversation AND the trapped-chest pry (via `choiceId`); a banked pry / quest reward rides
  the existing `LOOT_RESULT` (107) + `INVENTORY_UPDATE` (112). POI STATE (looted/questFlags) persists in the
  new `poi_state` table; POI positions stay 100% seed-derived (never stored).
- **§11.16 auto/walking timing.** `ATTACK.timing` and `USE_ABILITY.timing` accept
  **`0..1 | "auto"`** (null/absent === `"auto"`). At the `cmdWindowMs` deadline, unsubmitted heroes
  are auto-filled and resolved via the auto hit-chance path (§4.3).

## Invariants (every downstream milestone preserves)

1. The wire is the `OP` enum in `shared/protocol.ts` — nothing else is the contract.
2. `hello.protocolVersion` (`ProtocolVersion = 1`) gates out-of-date clients.
3. Server authoritative: clients send intents; state is real only when it returns in
   `snapshot`/`delta`/event.
4. §3 is language-neutral — a native client rebuilds from this table with no repo access.
