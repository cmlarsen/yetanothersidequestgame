# Combat Study — what makes turn-based combat addicting

> **Status: inspiration, not direction.** A pattern library to raid when combat
> next evolves — nothing here is committed. Survey of proven turn-based RPG
> combat patterns (comps deliberately span 1994–2023), scored for SideQuest's
> constraints: one thumb, 30–90 second fights, playable by kids, auto-battle
> must remain viable for walking mode. Goal per the design brief: combat as a
> **mini-game** — more than button-mash, less than chess.

## The core insight

Across thirty years of the genre, the games people call "addicting" all do the
same thing: **they put your hands and your brain on different problems in the
same turn.** The brain picks *what* to do (target, weakness, resource); the
hands are then tested on *how well* it happens (timing, execution). Menu-only
combat (classic Dragon Quest) engages only the brain — it becomes chess or
mash. Pure action engages only hands. The greats split the load.

A second, quieter insight: **the enemy's turn must be playable too.** Dead time
while the AI acts is where attention dies. The best systems make defense
interactive.

## The pattern library

### A. Timed hits / action commands — *the* combat-as-minigame pattern
**Exemplars:** Super Mario RPG (1996), Paper Mario, Mario & Luigi, Legend of
Dragoon (Additions), Shadow Hearts (Judgement Ring), South Park: The Stick of
Truth.
**Mechanic:** every attack has a tap-timing window — hit it for full damage /
a bonus, miss for a weak hit. Defense too: a well-timed tap when the *enemy*
strikes reduces damage (Paper Mario's guard).
**Why it's addicting:** every single action becomes a micro skill-check with
instant feedback; you can *feel* yourself getting better fight over fight.
**Fit: ★★★★★.** One-thumb native. And it solves our two open problems at once:
our invisible accuracy roll becomes a **visible moving window you tap** (the
Sure Hands training stat literally widens the window — practice-makes-mastery
made tangible), and enemy turns stop being dead air because you're watching
for the guard tap.
**Pitfall:** demanding perfect timing on *every* action fatigues (late Mario &
Luigi games). Mitigate: generous windows, and auto-battle simply resolves the
minigame at your trained accuracy.

### B. Weakness exploitation with turn economy — the "press turn"
**Exemplars:** Shin Megami Tensei III: Nocturne (2003) Press Turn; Persona's
One More → All-Out Attack; Pokémon's type chart (simplest form).
**Mechanic:** hitting a weakness doesn't just do more damage — it grants an
**extra action**. Missing or hitting a resistance *loses* actions. Symmetric:
enemies exploit your weaknesses the same way.
**Why it's addicting:** every new enemy is a small puzzle; solving it produces
an action-economy jackpot, not a 1.5× footnote. Team/loadout choice becomes
electric.
**Fit: ★★★★★.** We already have weak/resist (×1.5/×0.5) — the upgrade is to pay
the reward in *tempo*: hit a weakness → "**Breach!**" → act again immediately.
Perfect fiction fit (you tear a gap in their guard, through the veil). Makes
carrying an elemental sidearm genuinely matter.

### C. Visible intent — defense as planning
**Exemplars:** Slay the Spire (intents), Into the Breach (perfect
information), Darkest Dungeon (partial tells).
**Mechanic:** show what the enemy will do next; the player plans around it.
**Fit: already shipped** — our telegraph system is exactly this. Deepen by
showing the *number* ("Backstab — ~14 dmg") so Block/Dodge/race-to-kill
becomes an informed gamble.

### D. Risk-banking resources — the comeback pulse
**Exemplars:** Bravely Default (Brave/Default — spend future turns now or bank
them), FF Limit Breaks, Darkest Dungeon stress, Trails CP, For the King Focus.
**Mechanic:** a meter that accumulates *during* the fight creating spend-now-
or-save tension and comeback moments.
**Fit: ★★★★.** A **Focus meter charged by well-timed hits** (pattern A feeds
it) and spent on specials/guaranteed crits gives fights an arc: open, build,
cash out. Also the natural home for class specials later.

### E. Turn-order manipulation — time as a resource
**Exemplars:** FFX (CTB — visible future turn order you can delay/hasten),
Grandia (interrupt enemies mid-cast on the IP bar), Child of Light.
**Why it's great:** cancelling a boss's big cast by timing your hit is peak
turn-based drama.
**Fit: ★★ for now.** Too heavy for 30-second fights, but a light version is
nearly free: frost/shock already exist — "frozen enemies lose their telegraph"
is this pattern in miniature (we half-have it). Revisit for bosses.

### F. Position / formation
**Exemplars:** Darkest Dungeon (rank system), FF row system.
**Fit: ★ today** (one hero), **★★★★ later** when party NPCs / mercenaries land
— ranks are the cheapest way to make a 3-character party tactical on a phone.

### G. Legible randomness — show the dice
**Exemplars:** For the King, Dicey Dungeons; XCOM as the cautionary tale of
*hidden* percentages breeding distrust.
**Fit: ★★★.** We already show hit %. Pattern A supersedes this — a timing
window you missed is self-evidently fair in a way "87% missed twice" never is.

### H. Curiosities worth remembering
- **Earthbound's rolling HP** — lethal damage ticks down, letting you race to
  heal before it lands. Great drama, cheap to build; a boss-fight spice.
- **Undertale's bullet-hell defense** — the fully-realized "enemy turn is a
  minigame." Too twitchy for our frame but proves the principle.
- **Chrono Trigger dual techs** — combo abilities between party members; shelf
  until party NPCs exist.

## A candidate synthesis (inspo — one plausible combo, not the plan)

Current state: the *decision* layer is solid (targets, weaknesses, telegraphs,
block/dodge/potion, weapon choice). What's missing is the *execution* layer —
hands are idle while outcomes resolve. If we went this way, a four-piece combo
that fits our constraints, in ship order:

1. **Timed-tap attacks (A).** Replace the invisible accuracy roll with a
   moving sweet-spot tap. Trained accuracy = wider window; perfect tap = crit.
   RNG becomes skill you can feel. *(Biggest single upgrade.)*
2. **Timed guard (A, defense half).** A brief tap window as each enemy strike
   lands to shave damage — makes the enemy phase interactive, killing the last
   dead air in combat.
3. **Breach! press-turn-lite (B).** Weakness hit → one free follow-up action.
   Elements go from arithmetic to jackpot.
4. **Focus meter (D).** Charged by good timing, spent on a class special.
   Gives every fight an arc and future classes a signature.

Constraints honored: all one-thumb taps; fights stay 3–5 rounds; auto-battle
resolves minigames at trained-stat rates so walking mode is untouched; each
piece ships independently (1 alone is already a big win).

**Anti-goals:** no gesture/glyph systems (Wizards Unite's grave), no perfect-
information chess (Into the Breach is brilliant and wrong for us), no energy
costs on basic attacks, never mandatory reflexes — kids and auto-battle must
always have a path.
