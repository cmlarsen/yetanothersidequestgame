# SideQuest — World & Design Concept

> Status: **narrative / design pillar, not a spec.** Nothing here is committed to
> gameplay yet. It exists to give the world coherence and to steer future features
> (party NPCs, mercenaries, raids) toward one consistent fiction. Mechanics and the
> UI skin can keep evolving — this is the *why* underneath them.

## The core conceit

You are **not** playing a game set in a fantasy world. **The app is a lens.**

Your phone is a scrying device — a piece of glass that lets you see through the
thinning veil between our world and a parallel dimension pressed up against it.
The fantasy map, the monsters, the NPCs are really *there*, overlaid on the streets
and parks you actually walk through. The "game" is the interface to a real
(in-fiction) incursion happening around you.

This single idea reframes the whole real-world-map premise: the map looks
fantastical because you're seeing the **other world bleeding into ours**.

### Variant: the tome and the avatar (2026-07 — competing conceit, unresolved)

Same two worlds, different relationship to them: the phone isn't a lens you
see through — it's an **enchanted tome**, a portal *communication* device.
Your hero is an **avatar in the other realm**; you direct it from here. Your
apprentice, gear, camp — all of it exists over there, which is why none of it
is visible in our world.

What this variant fixes that the lens can't:

- **The bystander problem.** Under the lens, you're personally swinging at a
  wraith in the park — why doesn't your neighbor see? Under the tome, nothing
  happens in our world: someone quietly reads a book-shaped device while the
  fight happens over there.
- **Death, distance, and the bus.** Wake-at-camp is literal (the avatar
  retreats; you were never in danger). Fighting from a bus stop makes sense.
  Away-progress makes sense — the avatar's world runs while the tome is shut.
  The safety design (never approach the busy street) stops being a UI apology.
- **Turn-based combat becomes diegetic.** You're *relaying commands across
  the veil* — orders take a beat, reports come back. The combat system is the
  latency of a portal device, not a genre convention.
- **The apprentice becomes the voice on the other end** — the one actually
  *there*, describing what they see while you decide. A radio-operator
  relationship (the Zombies, Run! shape), which makes the future audio
  "running mode" already in-fiction, and makes one character the snark
  vehicle, tutorial voice, and audio mode at once.
- **Geography survives.** The realm is pressed against ours; the avatar moves
  through the *mirror* of your neighborhood — walking here moves your anchor
  there. Proximity bands get a fiction: the link is strongest where you stand.

The cost: it steps the player back from "I *am* the hero" toward "I *operate*
a hero" — and the genre law says the fantasy on the tin must be the fantasy
in the loop. Sub-variant that keeps the benefits and dodges the cost: the
avatar is **you, projected** — the tome casts your presence across the veil;
the body over there is yours the way a reflection is yours. (Whether the
avatar has its *own* personality decides this — a snarky avatar plus a snarky
apprentice may be one snark too many.)

Arc note: keep the stakes as "monsters breaking into *our* world" — you fight
at mirror-side breach points precisely so things *don't* appear here, and the
convergence arc's late-game gut-punch is the first time one does.

## The two worlds and the failing barrier

- **This world** — the ordinary one you physically move through.
- **The Other** (working name) — a parallel dimension of magic and monsters, pressed
  against ours.
- Between them, a **veil / barrier** that has always kept the two apart. It is now
  **thinning and breaking.** Where it fails, the worlds **converge**: rifts split open,
  portals form, and things cross over.

Signs of the breaking, surfaced diegetically in the app: shimmering tears in the air,
portals at points of interest, and zones where the overlap is strong enough that
monsters can physically manifest on our side.

## The factions

Everyone you meet is a real actor in the Other world, not set dressing:

- **The Breach** *(antagonists)* — monsters and the leaders driving them, actively
  working to *widen* the rifts and break fully through into our world. Left unchecked,
  they succeed. Every unanswered incursion pushes the barrier further open.
- **The Wardens** *(allies)* — denizens of the Other world (and a rare few from ours)
  trying to *hold* the barrier. Quest-givers, the merchant, future mercenaries — these
  are Wardens, or opportunists working the border-zone, who need a champion on this side.
- **You** — one of the rare people who can both *see* through the veil and *act* on it.
  A Warden by circumstance.

## Why the mechanics are what they are (diegetic mapping)

The framing retro-justifies what we've already built — a good sign it's the right story:

| Mechanic today | In the fiction |
| --- | --- |
| Real map + proximity quests | Incursions happen at real places near you; you patrol the border in your own neighborhood. |
| Travel → combat | Reaching a rift and repelling what's pushing through before it fully crosses. |
| Difficulty tiers (Elder → Massive) | How far a given rift has torn open. A Massive foe = a rift near collapse. |
| "Unsafe / inaccessible" quests we reject | Places where the veil is too violent, or the spot is unreachable in the real world. |
| Bounties | Culling specific breeds before they establish a foothold. |
| Quest-giver **Hut** / NPCs | Wardens on the other side calling for help; you return to them because that's where the veil is stable enough to parley. |
| Wandering **Merchant** | A border-walker who trades goods across the veil. |
| Resting → passive materials, gold, **Downtime Points**, lucky finds | The barrier settling while you're away, leaving residue / essence — and the occasional thing washed through — to gather on your return. |
| Away-time **crafting** (queued jobs finish while the app is closed) | Warden artisans work your commissions across the veil on their own time. |
| Walking → **Endurance Points** → trained abilities (QfG-style: the skills you walk for are the ones that grow) | Patrolling the border hardens you; mastery is earned by practice, not granted by levels. |
| **Bastion** tiers (Downtime sink) | Fortifying your anchor on this side of the veil. |
| Death → wake at camp | You're pulled back to your side of the veil — wounded, not lost. |
| Camp | A place where the veil is calm; your anchor on this side. |

## The arc: convergence

The long game is the barrier failing further over time — a slow **convergence**. Rifts
multiply, then begin to **link and merge** into larger tears. This is the natural home
for the eventual raids / large events: a major convergence where many players (or a
full party) must close a collapsing rift together before it becomes permanent.

## Future hooks (aimed at, not built)

- **Party NPCs** — recruit Wardens to fight alongside you; a small squad that crosses
  rifts with you.
- **Mercenaries** — hire border-world fighters with gold for tough incursions; allies of
  convenience rather than conviction.
- **Higher allies** — earn the trust of powerful Warden figures who grant boons, gear, or
  safe passage through dangerous zones.
- **Named antagonists** — Breach leaders behind regional surges; recurring rivals with
  their own agendas.
- **A convergence clock** — a world-state that escalates if incursions go unanswered,
  tying the moment-to-moment loop to the raids / persistent-world (MUD) vision.
- **Portals & rift visuals** — dimensional tears that visibly widen, split, and converge
  on the map as the state of the barrier changes.

## Open questions

- Names: "The Other," "The Breach," "The Wardens" are placeholders — worth finding names
  with more character.
- How visible is the two-worlds framing to a brand-new player? A cold-open that literally
  shows the veil tearing on first launch, vs. letting it emerge through quest text.
- Is the convergence a global shared state (everyone's world degrades together) or local
  to each player? This decision gates the raids design.
- Where do *human* characters from our side fit — other seers, skeptics, a shadowy org
  that knows about the veil?
