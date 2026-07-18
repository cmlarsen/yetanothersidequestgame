# protocol-gen

Generates the GDScript mirrors of the server's wire contract and tuning
constants (the server is the source of truth):

- `game/src/net/server_protocol.gd` — `ServerProtocol`: `VERSION`,
  `WS_PATH`, and the full `OP` name → wire-number dictionary.
- `game/src/data/server_tuning.gd` — `ServerTuning`: `VALUES` (every scalar
  export of `server/shared/tuning.ts`, nested groups as nested dictionaries)
  and `XP_CURVE` (the server-rounded level curve).

## Usage

```sh
cd server && npx tsx ../tools/protocol-gen/generate.ts
```

Run from `server/` so the script reuses the server's `node_modules`
(tsx, zod) — this package deliberately declares no dependencies of its own.

Output is deterministic (stable key ordering), so a server change regenerates
with a minimal diff. `game/tests/data_sanity.gd` asserts the shell's `Rules`
constants match `ServerTuning` — drift fails `tools/dev/check.sh`. After the
files first appear (new `class_name` scripts), run
`godot --headless --path game --import` once.
