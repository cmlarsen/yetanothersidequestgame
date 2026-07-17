# North Star — goals, audience, tone, and open questions

> Status: **the closest thing to answers we have.** Captured 2026-07 from a
> direct Q&A pass over the gaps in the design bible. Most open questions are
> expected to resolve by riffing, not by deciding early.

## The goal ladder

Each rung is a real success even if the next never comes:

1. A game my 13-year-old wants to play — **and wants his friends to play with
   him.**
2. A game *I* want to play, that gets me outside moving and running (running
   is admittedly deeply niche).
3. A game I want strangers to play.
4. A game that makes enough money to pay for itself.
5. …enough to justify working on it.
6. …enough to go part-time.
7. …enough to live on.

Note what rung 1 implies: the first social unit is a **friend group of
13-year-olds**, not App Store strangers. "Play *with* his friends" is a
launch-tier requirement, not an expansion.

## Decided (lightly held, like everything)

- **Online.** Shared, persistent world is core to the vision, not a bolt-on.
  (Corollary: server costs make rung 4 a design input, not an afterthought.)
  Likely home: **fly.io** — already hosting other projects cheaply. The
  deterministic-world decision (MAP-DATA) keeps the server tiny: player saves,
  friend links, shared events only — one small machine + SQLite, scale-to-zero.
  Tigris (Fly's object storage) can also serve the PMTiles map tiles.
  Posture: **server-authoritative, like PoGO** — the shared world lives on
  the server, which is also the only credible anti-cheat stance (a fully
  offline-playable client is one a 13-year-old's friends will learn to give
  themselves 9,999 gold on, and cheating poisons the *shared* world). Design
  courtesy, not architecture: tolerate brief dead zones gracefully (finish
  the current fight from cache, queue the result) — this is a game about
  going outside, and trailheads have no bars.
- **Audience: adults and kids — the PoGO shape.** Kids welcome, not marketed
  or targeted at 8-year-olds; not trying to skirt regulations. Tone
  calibration: would a 13-year-old think it's cool?
- **Content ships in seasons.** Solo dev + Claude is judged sufficient for a
  seasonal cadence.
- **Audio comes after core mechanics.** Likely high-quality AI-generated
  voices, pre-generated lines — with an honest asterisk: AI voice is a
  sensitive subject in the games world, so unclear. Possibly debuts confined
  to the headless "running mode," where audio-first is the whole point.
- **Prototype definition of done:** the final prototype shows the game loop
  *works* — the tell being that its owner is **annoyed** it isn't persistent,
  isn't shared, and friends can't be invited. That itch is the signal to
  build the real thing.
- **Name:** SideQuest, emotionally — with real synergy: the maker YouTube
  channel *Yet Another Side Quest* is a ready-made audience/acquisition
  channel. Another name is allowed to win later. (Trademark sanity check
  still owed: SideQuestVR collision.)

## Emotional target

**Quest for Glory is the tonal ancestor.** Snarky sidekicks, NPCs with
attitude, adventure with a wink. Knights of Pen and Paper is a secondary
touchpoint — but probably *without* breaking the fourth wall.

The register, stated once:

> Not "oh so serious" fantasy — you should never need to care about the lore
> to play. Not a joke either. The fights are tense, the words are warm, and
> every once in a while a dialogue line earns a snort-laugh. If it does,
> we're delighted.

Guardrails that fall out of this:

- Lore is seasoning, never homework — the veil fiction stays in the
  background for anyone who doesn't chase it.
- Snark lives in *characters* (sidekick, merchants, quest-givers), not in the
  UI or narrator.
- Fourth wall stays intact.
- Humor is earned and occasional, not wall-to-wall.

This retro-validates two things already in the bible: the apprentice (the
natural snark-delivery vehicle — see RIFT-BRIEF) and the personality-forward
merchants (Grimble & Sons is exactly this register).

## Still open (expected to emerge by riffing)

- Precise audience definition beyond "PoGO shape" (TBD by design evolution).
- The first five minutes / cold open — TBD as the game evolves; flagged as
  our main Wizards-Unite risk in GENRE-LESSONS.
- Cold-start content density (thin suburbs / small towns).
- What "kids welcome, online game" requires concretely (COPPA-aware
  defaults) once social features are real.
- Playtest discipline: what we measure with the kids; what result kills a
  beloved idea.
- Native stack (SwiftUI+SpriteKit vs Unity vs wrapper) — partially
  constrained by MapLibre choice; decide when the prototype has done its job.
- What shape "play with friends" takes first (shared camp board? co-op tear?
  visible friends on the map?) — rung 1 says this comes earlier than the
  raids end-state.
