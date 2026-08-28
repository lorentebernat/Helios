# Helios — Phased Roadmap

Companion to `HELIOS_DESIGN.md` (current state + decision log) and
`OGAME_COMPARISON.md` (the transfer analysis this plan acts on).

Helios is deliberately an **Anno–OGame hybrid**. This document records what was
settled, why, and the order of work.

---

## 0. Guiding principles

**Take OGame's mechanisms; keep Anno's centre of gravity.**
Anno is a *flow* game — value lives in throughput, interlocks, and the tier
squeeze. OGame is a *stock-and-exponent* game — value lives in accumulated
numbers. OGame's three genuine gifts (production factor, offline catch-up,
levels) are all stock-side mechanics. Bolted on carelessly they would pull Helios
toward "watch numbers grow while away," hollowing out the flow game. So: **levels
and plots exist to make choices scarce, not numbers big.**

**Offline accumulates; sessions decide.**
At honest 1/60 pacing, eight hours away yields ~480 game-minutes of output while
a five-minute session yields five. Offline will always dwarf active play — so
active play must not be *about* output. Absence generates materials. Presence is
where the player retasks chains, sets output percentages, upgrades buildings, and
dispatches ships. This is the north star for every pacing number.

**Play pattern:** both. Short sessions, offline continuity between them.

**No win condition.** The game is endless. Long-term motivation comes from
multiplayer (see §3), not from completion.

---

## 1. Settled decisions

| Question | Decision |
|---|---|
| Scarcity model | **Universal proportional allocation.** `ChainStatus` keeps its three cases as the *reason*; a new `throughput: Double` carries the *magnitude*. A chain reads as "running at 60%". Kills array-order dependence; smooths the knife-edge oscillation. Also more Anno — Anno factories degrade rather than hard-halt. |
| Levels | On a new **`Building`** concept, not on chains directly. Note that Helios's chains *already are* buildings — "Ice Harvester" is a building running a chain — so `Building` spans production plus the Habitat / Storage / Defense categories the chips already name. Unifies the taxonomy and finally gives the category chips a job. |
| Level exponents | ~`1.1` output / `1.5` cost. **Cost's base must stay above output's** or later levels get cheaper in real terms and pacing inverts. |
| Plot cap | **Yes.** Cheapest to add now. It's what makes world types and multi-colony mean anything, and it must land *together* with levels — levels without a cap is "build everything, slightly better"; a cap without levels is pure restriction. |
| Trade | **Both, in order.** Discrete missions first (dispatch is already built). Standing-route automation unlocked *very late* in progression — better logistics as a reward, which is very Anno. |
| Shipping colonists | **No.** Protects the workforce squeeze. Ship the needs, not the needers. |
| Loss | **Yes, bounded.** Hazards take only stock *above* storage capacity — never population, never buildings. Different hazard types differ in severity: raids steal *and* destroy more; environmental events are milder. Makes storage protective as well as productive. |
| Colony scope | **Per-colony from Phase 0.** Restructuring before buildings and plots land is far cheaper than after. |
| Large numbers | Compact notation (`1.2M`, `3.4B`) planned for when numbers actually grow, not built speculatively. |

### Scope split (following Anno's precedent: gold global, goods and population per-island, ships global)

| Empire — `GameState` | Colony |
|---|---|
| `credits` | `colonyStock` |
| `ships`, `shipyardQueue` | buildings / production chains |
| research points & projects | `population` |
| score | world identity, plots, energy grid |
| `colonies`, `activeColonyID` | `lastUpdated` |

---

## 2. Phases

### Phase 0 — Structure
*Cheap now, painful later. Nothing here is interesting; all of it gets more
expensive the longer it waits.*

- Split `rateMultiplier` into `economyRate` and `fleetRate`
- Empire / Colony split (one colony in an array; switcher UI waits for Phase 6)
- Restore the missing `PlanetBackdrop` on `MainColonyView`
- Wire material costs into `BuildCost` (already unblocked by `ColonyStock`)
- **Multiplayer hedges** (see §3): keep tick logic in pure value types with no
  SwiftUI/Observation dependency; store `lastUpdated` timestamps; keep randomness
  out of the tick or seeded; add coordinates to `Destination`

### Phase 1 — Unified throughput
*The highest-value phase. Closes three open items at once.*

This departs from `OGAME_COMPARISON.md`'s ordering, which treats energy factor,
output %, and workforce as separate items. They aren't: **all three are
throughput multipliers on the same `scale`**, and the comparison doc itself flags
that workforce and energy need a defined combination rule. Designing them
together settles that rule once.

- Energy as a live per-colony balance (never stored), producing a colony factor
- Workforce as a second factor — **Anno's squeeze, the piece OGame can't teach**
- Player-set output % per chain as a third
- One combination rule (multiply is harsher and more legible than min)
- `throughput: Double` alongside `ChainStatus`
- UI: a "Grid" readout on the colony screen; per-chain throughput display

Closes: *scarcity is crude*, *energy as universal requirement*, *workforce*.

**Note:** energy producers are themselves chains. Compute the factor from the
previous tick's running set, or exempt energy producers from their own throttle —
otherwise a brownout is self-reinforcing and the colony can never recover.

### Phase 2 — Fleet ↔ economy loop

- Cargo as a real integer quantity
- **Loading is a withdrawal**, arrival is a deposit
- Fuel and the speed slider ride along or defer

The withdrawal rule is the comparison doc's best small insight: it turns the
fleet from a money faucet into a participant, and an over-ambitious shipment
starving a chain is a good, diagnosable failure. Also discharges part of the
standing rule on display-only ship stats.

### Phase 3 — Honest pacing + offline

- Dial `economyRate` to 1/60
- Tick-replay catch-up on resume, with a cap

Deliberately *after* Phases 1–2. Replay simply re-runs `tick()`, so the later it
lands the more it covers for free — and accelerated pace is far better to develop
against. Replay (not closed form) is mandatory anyway: the sim is path-dependent.

### Phase 4 — The vertical axis
*The largest phase; likely splits into 4a/4b.*

- A `Building` concept spanning production, Habitat, Storage, Defense
- Levels with the `1.1` / `1.5` exponents
- Plot cap per colony
- World-type production modifiers (Ice, Arid, Oceanic, Volcanic, Gas Giant)
- `Resource.capacity` stops being static — storage becomes a levelled building

These must arrive together. Also: OGame halts *per resource* where Helios halts
*per chain* — finer granularity is probably wanted eventually, and this is the
phase to consider it.

### Phase 5 — Legibility

- Colony score with economy / research / military / defence sub-scores
- Population thresholds gating `ResearchProject` availability
- Research global vs local split (settle before multi-colony)
- **`MainColonyView` redesign** — by now it must absorb a Grid readout, a score,
  and throughput badges, so the redesign belongs here rather than earlier

### Phase 6 — Multi-colony

- World-switcher UI
- Discrete missions proper
- `.docked` still reserved (it activates with route automation, not here)

### Phase 7 — Risk & combat

- Hazard types with differing severities
- Combat resolver (~60 lines; per-hit explosion roll, rapidfire re-roll,
  shields regenerating between rounds — the swarm-beats-few property matters)
- Discharges the standing rule on `shields` / `weapons`

### Phase 8 — Asynchronous multiplayer
*See §3. Server work, not client work.*

---

## 3. The multiplayer end-state

**Asynchronous multiplayer in a shared persistent galaxy**, with trade, raids,
and battle against other civilisations. **Server-authoritative from the start** —
a client-authoritative economy is trivially editable, which is indefensible once
raids exist.

### The constraint this imposes on everything before it

OGame can project resources client-side because its production is **linear** —
the browser interpolates a counter between page loads. Helios cannot. The sim is
**path-dependent**: chains stall and throttle, population promotes and declines,
energy and workforce scale everything. There is no closed form to interpolate.

So the client will have to **run the same simulation locally as a prediction** and
reconcile against server snapshots. That requires the sim to be deterministic and
identical on both sides — the same code ideally; beware floating-point divergence
if the server isn't Swift. **This is the real argument for keeping
`SimulationCore` a portable, UI-free module** rather than letting tick logic marry
SwiftUI.

### Hedges adopted in Phase 0

All good hygiene regardless of whether multiplayer ships:

- `applyTick` logic stays in pure value types — no SwiftUI, no Observation
- `lastUpdated` timestamps stored rather than assuming continuous ticking
- Randomness kept out of the tick, or explicitly seeded
- `Destination` gains coordinates so distance is *computed*, not authored — a
  shared galaxy needs positions (OGame's `galaxy:system:position` shape, and the
  reason it uses `t ∝ √distance`)

### One design warning

The colony score stops being harmless once it's a public ranking.
`OGAME_COMPARISON.md` notes that OGame's points double as a raiding-target
indicator and distort play — people deliberately stay small. Phase 5 must design
the score knowing it will eventually be public.

---

## 4. Explicitly not taking

From `OGAME_COMPARISON.md` §4, plus consequences of the decisions above:

- Dark Matter, officers, classes — monetisation and account-level modifiers
- Flat, chainless production — Helios's chains are strictly more interesting
- Points-as-raiding-target — take the score, design against the distortion
- Twelve-hour build times — adopt the exponential *shapes*, not the durations
- Deep combat minutiae (the 1% shield bounce rule and similar)
- Closed-form offline solving — impossible here; replay instead

---

## 5. Still open

- The combination rule for stacked throughput factors: multiply or minimum.
  (Multiply is harsher and more legible; decide in Phase 1.)
- Per-resource vs per-chain halting granularity (Phase 4).
- Research global vs local, or split by `ResearchCategory` (Phase 5).
- Whether hazards are purely environmental pre-multiplayer, or whether PvE
  raiders exist in Phase 7.
- Tier 3–5 needs (Engineers, Synthesists, Ascendant) remain placeholders, to be
  designed with the fuller resource network.
- Ellipsis menu contents per screen.
