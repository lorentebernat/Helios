# OGame → Helios — Mechanics Comparison & Transfer Report

A structured read of OGame's systems against Helios's current build, its known gaps,
and its open design questions. Written to feed the decision log: every transfer is
presented as **options with trade-offs**, not a prescription.

Source material: OGame Wiki (fandom + sidian), Gameforge official pages, community
calculators and forum balance threads, August 2026. Formulas are community-derived
and verified against in-game values, not official source code — treat the exact
constants as strong estimates and the *shapes* as reliable.

---

## 0. The thesis, in one paragraph

Anno 1800 — Helios's stated ancestor — is a **flow game**: value lives in throughput,
chains, and the tier squeeze, and the player's skill is in balancing rates. OGame is a
**stock-and-exponent game**: value lives in accumulated numbers, every curve is
exponential, and the player's skill is in compound-interest planning under a
time-and-risk constraint. That difference means most of OGame is *not* directly
applicable to Helios. But OGame has been running continuously since 2002 and has been
forced to solve, at scale, three problems Helios currently has open — **partial
scarcity, offline progress, and a progression axis for buildings** — and it solves all
three with mechanics that are simpler than what Helios would likely invent. Those are
the transfers worth taking. The rest is context.

---

## 1. System-by-system map

| System | Helios today | OGame | Verdict |
|---|---|---|---|
| Resource model | Colony-wide pool, per-resource capacity, emergent chain linking | Per-planet stock of Metal / Crystal / Deuterium, no chains at all — mines produce from nothing | **Helios is richer.** Nothing to take from the resource model itself. |
| Scarcity | Binary halt, first-come-first-served by array order | **Production Factor**: energy deficit scales *every* producer proportionally | **Take it.** Direct answer to the "scarcity is crude" gap. §3.1 |
| Player priority | None. Array order silently decides who starves | Per-mine output % slider (recalculate button) | **Take it.** Cheap, uses the same plumbing. §3.2 |
| Energy | Planned: Power Plant produces energy as a universal chain requirement | Energy is not stored — a live balance; deficit throttles production | **Take the model wholesale.** It's exactly the design already intended, and it arrives with the throttle. §3.1 |
| Building progression | **None.** Chains have fixed rates, no levels, no upgrades | Every building has levels; output ×1.1^L, cost ×1.5^L | **Biggest gap in Helios.** §3.3 |
| Storage | `Resource` declares a static per-resource capacity | Storage buildings, capacity `5000·⌊2.5·e^(20L/33)⌋`; production stops at cap but overflow from transports is kept | **Take the upgrade axis and the overflow rule.** §3.4 |
| Simulation | Tick loop, `rateMultiplier = 1.0`, no offline progress | Pure timestamp/closed-form; server never ticks anything | **Take the closed-form for catch-up**, keep ticks for the foreground. §3.5 |
| Pacing lever | Single `rateMultiplier` | **Two** separate multipliers: economy speed and fleet speed | **Split yours before you dial it to 1/60.** §3.5 |
| Build space | Unlimited chains per colony | Hard **fields** cap per planet, one field per building regardless of level | **Strong candidate.** Makes every chain a choice and makes multi-colony matter. §3.6 |
| Population | 5-rung distribution, needs, happiness 0–1, promotion, workforce planned | Lifeforms: population + food per planet, capped by housing, gates tech slots. No tier-drain squeeze | **Helios's design is better for its genre.** Take two rules only. §3.9 |
| Ship cargo | Display-only string | Integer capacity; fuel is deducted at launch and *occupies* cargo space | **Take it.** Closes the Fleet↔Production loop and honours the standing rule. §3.7 |
| Travel | `travelTime / speedMultiplier`, linear in distance | `t ∝ √distance`, with a 10–100% speed slider that trades fuel for time | **Take the slider**, consider the √. §3.7 |
| Combat | None. `shields` / `weapons` are invented numbers | ≤6 rounds, random targeting, shield→hull, explosion roll, rapidfire | **Take the algorithm verbatim** when you're ready. It's ~60 lines. §3.8 |
| Multi-colony | Deferred; world types exist as flavour | Colonies gated by Astrophysics; planet **position** and **temperature** change output | **Make world type a production modifier.** §3.10 |
| Research | States + categories; points from Ascendants | Cost roughly doubles per level; empire-wide; gates ships and colony count | **Take the global/local split** before multi-colony lands. §3.11 |
| Progress metric | None | Points = resources invested ÷ 1000 | **Take it.** One line, big legibility win. §3.12 |
| Trade | Deferred; `.docked` reserved for routes | No standing routes — discrete missions + a dark-matter merchant at ~3:2:1 | **A fork in the road.** §3.13 |
| Risk / loss | None | Stock is raidable; storage cap defines what's exposed | Optional, but it's what makes OGame's loop tense. §3.14 |
| Premium / officers | None | Dark Matter, officers, classes | Ignore. §4 |

---

## 2. What OGame does that Helios has no analogue for at all

Listed so nothing is silently dropped:

- **Levels on everything.** There is no "a building" in OGame, only "a building at level L".
- **A hard field limit** per planet — the actual strategic constraint of the whole game.
- **Loss.** Resources above the protected threshold can be stolen; fleets can die.
- **Other players.** Every economic decision is priced against raiding income.
- **Fleet save** — the emergent mechanic where players launch their fleet before logging
  off so it cannot be attacked mid-flight. Nobody designed this; it fell out of the rule
  "fleets in transit are untargetable."
- **Expeditions** — a slot-limited gamble loop (send fleet to deep space, roll on a table).
- **Debris fields and moons** — destroyed fleets leave 30% of their metal/crystal in a
  harvestable field; a large enough field can spawn a moon (chance = debris ÷ 100,000,
  capped at 20%).

---

## 3. The transfers, in detail

### 3.1 Production Factor — one mechanic that closes two Helios gaps

**How OGame does it.** Mines consume energy. Energy is not a stored resource, it is a
live balance between production and consumption on that planet. If consumption exceeds
production, the game computes a **production factor** = available ÷ required, and every
producer on the planet runs at that fraction. Factor 0.5 means every mine yields half.
The player sees the factor as a number above the resource table. There is no halting,
no queueing, no priority resolution — just a scalar.

Reference shapes:

```
Metal Mine output/hr    = 30 · L · 1.1^L
Crystal Mine output/hr  = 20 · L · 1.1^L
Deuterium output/hr     = 10 · L · 1.1^L · (1.44 − 0.004 · T_max)
Mine energy draw        = ⌈10 · L · 1.1^L⌉   (metal & crystal; deuterium ×2)
Solar Plant output      = 20 · L · 1.1^L
Fusion Reactor output   = 30 · L · (1.05 + 0.01 · EnergyTech)^L   — burns deuterium
```

**Why this matters for Helios.** The design doc has two separate open items:

> *Richer chains and resources* — the Power Plant should produce **energy** as a
> universal requirement every chain needs to function.
>
> *Scarcity is crude* — binary halt, first-come-first-served by array order. Array order
> silently determines who starves.

These are the same problem. Energy is the shared input that *every* chain competes for,
which is precisely the case where binary halting is worst — with nine chains and one
energy pool, array order would decide the entire colony's behaviour. OGame's answer is
to never let a shared input cause a halt at all; it causes a **throughput multiplier**.

**Option A — energy-only throttle.** Energy alone is proportional; material inputs keep
the existing binary block.

- *Pro:* smallest change. `ChainStatus` keeps its three cases. One new field on
  `GameState` (`energyFactor: Double`), one multiplication inside `applyTick`. Energy
  becomes visibly different from a material input, which is the stated intent.
- *Con:* two scarcity philosophies coexist. Material contention is still array-ordered.

**Option B — universal proportional allocation.** Every input is allocated
proportionally; a chain short on Grain runs at the fraction of Grain it can get.

- *Pro:* array order stops mattering anywhere. Shortages become graceful degradation, and
  the "knife-edge oscillation" noted in §7 of the design doc smooths into a stable
  equilibrium — the economy self-balances instead of flapping.
- *Con:* `ChainStatus` is no longer a clean three-state enum. You'd need
  `throttled(factor:)` or a separate `throughput: Double`, which pushes against the
  "enum over nullable" principle. Also two passes per tick (compute demand, then run),
  which is a real change to the tick contract. And "nothing is ever fully blocked" is
  harder to surface in UI than a red badge — degradation is less legible than failure.

**Option C — hybrid.** Proportional for energy and for any resource flagged
`isDivisible` (power, water, feedstock); binary for discrete goods (tools, components).

- *Pro:* matches intuition — you can half-power a smelter, you can't half-deliver a tool.
- *Con:* a new axis of authored data to keep consistent.

**Sketch (Option A):**

```
// GameState.tick(), before the chain loop
let produced = chains.filter(\.isRunning).reduce(0) { $0 + $1.energyOutput }
let required = chains.reduce(0) { $0 + $1.energyDraw }
energyFactor = required <= 0 ? 1.0 : min(1.0, produced / required)

// inside ChainDetail.applyTick(perMinToTick:stock:energyFactor:)
// after the stall and input checks pass:
let scale = perMinToTick * energyFactor
// consume inputs × scale, produce outputs × scale
```

Note the ordering hazard: energy producers are themselves chains. Compute the factor from
last tick's running set, or exempt energy producers from their own throttle — otherwise a
brownout is self-reinforcing and the colony can never recover. OGame sidesteps this by
making solar plants not consume energy at all; the simplest fix is the same rule.

**UI consequence.** The factor wants to be visible. A single "Grid: 78%" readout on
`MainColonyView` — amber below 1.0, per the reserved-colour rule — is the whole feature.
OGame's version is literally one number above a table and it has carried the mechanic for
two decades.

---

### 3.2 Player-set output percentage

**How OGame does it.** Each mine has an output % (0–100 in steps of 10). Lowering one
mine's output lowers its energy draw proportionally, which raises the production factor
for everything else. It's a manual priority system built entirely out of the throttle
that already exists — no priority weights, no ordering rules, no allocation algorithm.

**Why it matters.** The design doc names the fix as *"priority weighting, proportional
allocation, or player-set priorities."* This is the third one, and it's free once §3.1
exists: `chain.outputPercent: Double = 1.0`, folded into `scale`.

- *Pro:* zero new systems, zero new authored data, and it converts a hidden fairness bug
  into a player-facing decision. Turning the Alloy Smelter down to 50% to keep the
  Hydroponics Bay fed is a *good moment* — it's the player noticing an interlock they
  discovered themselves, which is the payoff of the colony-pool design.
- *Con:* micromanagement surface. On mobile this needs to be a coarse stepper (0 / 25 /
  50 / 75 / 100), not a continuous slider. OGame's steps-of-10 is already a concession to
  this and is arguably still too fine.
- *Also:* it makes the chain list's per-row UI heavier, which cuts against the
  already-noted `MainColonyView` crowding. The stepper probably belongs on
  `ProductionDetailView`, with only a "50%" badge in the list row.

---

### 3.3 Levels and the cost-vs-output exponent — Helios's largest structural gap

**How OGame does it.** Nothing in OGame is built once. Output scales `1.1^L`; cost scales
`1.5^L`. Cost outruns output permanently, which is the entire pacing engine of the game:

| Metal Mine level | Output/hr | Approx. cumulative metal cost | Payback |
|---|---|---|---|
| 10 | 778 | ~30k | ~2 days |
| 20 | 4,038 | ~1.9M | ~3 weeks |
| 30 | 15,700 | ~110M | ~9 months |

The wiki even gives a closed form for payback time: `(3 / (4L)) · (15/11)^L` hours. The
`15/11` is `1.5/1.1` — the ratio of the two exponents *is* the pacing curve. Every
"should I upgrade the mine or build a fleet?" decision in OGame is a read of that ratio.

Build time uses the same trick in reverse: it scales with cost but is *divided* by
Robotics Factory level and halved per Nanite Factory level, so infrastructure investment
buys back time — a second, orthogonal upgrade axis.

**What Helios has.** Nine chains at fixed rates. There is no way to make the Ice Harvester
better. Progression is currently entirely horizontal: unlock more chains, grow population,
research. There is no vertical axis, and therefore no long-term goal, no meaningful
resource sink after the initial build-out, and no reason for the credits balance to exist
beyond ships.

This is the gap that most limits Helios's session count. Everything else on the roadmap
(workforce, cargo, offline) deepens the current loop; levels are what give the loop
somewhere to go.

**Options:**

- **A — levels on chains.** `ChainDetail.level`, rates × `1.1^L`, cost × `1.5^L`.
  *Pro:* smallest change, one field, immediate depth, reuses the shipyard-queue shape for
  build time. *Con:* nine chains × N levels is a lot of numbers to balance, and it makes
  every chain a spreadsheet row rather than a decision.
- **B — levels on buildings, chains stay flat.** Ties into the deferred *construction
  mechanic* and the Habitat chip. Chains are what a building does; the building is what
  levels. *Pro:* aligns with the already-planned taxonomy (Power / Storage / Habitat /
  Defense / Life Support), gives the category chips a real job instead of being cosmetic,
  and lets one upgrade affect several chains. *Con:* requires the building layer to exist
  first — a bigger commitment.
- **C — research-only vertical.** Multipliers come from `ResearchProject` completions.
  *Pro:* the system already exists and is currently a dead end (research completes and
  then does nothing mechanical). *Con:* global rather than local, so it can't create
  interesting per-colony divergence later.

The exponents themselves are worth stealing regardless of which shape wins. `1.1` output /
`1.5` cost is a well-tested pair; the derived `(15/11)^L` payback curve gives you a
balance check you can compute rather than playtest. If Helios's tick is a game-minute and
a session is minutes long, the base may need to be gentler (`1.08` / `1.4`) — but keep
cost's base above output's, or the game inverts and later levels become *cheaper* in real
terms, which collapses pacing.

---

### 3.4 Storage caps as a pacing device

**How OGame does it.** Storage capacity is `5000 · ⌊2.5 · e^(20L/33)⌋` — exponential,
starting at 10,000 with no storage building. When a resource hits its cap, **production of
that resource stops**. Crucially, resources delivered *by transport* above the cap are
kept, not destroyed; only production halts. And storage interacts with raiding: stock
above the cap is fully exposed.

**Why it matters for Helios.** Three things:

1. **Validation of the existing stall check.** Helios already halts a chain when its output
   pool is full, preserving inputs. That's the same rule, and OGame's twenty-plus years
   are decent evidence it doesn't feel bad. Keep it.
2. **Difference worth noting.** OGame halts *per resource*, Helios halts *per chain*. When
   a chain has two outputs and one is full, Helios stops both. OGame's granularity is
   finer and is probably what you want eventually.
3. **Storage as an upgrade path.** `Resource.capacity` being static is a missed lever.
   Making capacity a levelled colony building turns "my Ice stock is capped" from an
   annoyance into a purchase decision, and it is the mechanic that makes offline progress
   interesting — see next.

---

### 3.5 Timestamp simulation, offline catch-up, and two speed multipliers

**How OGame does it.** OGame does not tick. Resources are stored with a `last_update`
timestamp and computed on read: `stock = min(cap, stock + rate × elapsed)`. Buildings,
research, and fleets are rows with completion timestamps. This is why the game can run
hundreds of thousands of accounts on modest hardware and why "offline progress" isn't a
feature — it's the only mode that exists.

**Mapping onto Helios's roadmap item.** The doc's next-up item is *dial `rateMultiplier` to
1/60 and catch up on elapsed wall-clock at resume*. Two ways:

- **A — replay ticks.** On resume, run `elapsedMinutes` ticks in a loop.
  *Pro:* one code path; the offline result is exactly the online result, so no divergence
  bugs. Population promotion, chain blocking, and shipyard progress all behave identically.
  *Con:* 8 hours away = 480 iterations of nine chains plus population plus fleet. That's
  fine. 3 days away = 4,320 iterations, still fine. It only becomes a problem if the tick
  gets much heavier or you ever want month-long absences.
- **B — closed form.** Compute end state analytically.
  *Pro:* instant regardless of elapsed time. *Con:* you must reimplement every rule in
  closed form, and any rule with feedback (blocking, promotion, energy factor) is not
  analytically solvable — you'd end up approximating, and the offline economy would drift
  from the online one. This is why OGame can do it and Helios can't: OGame has no
  interlocks. Its mines don't depend on each other.
- **C — coarse replay.** Replay ticks but with a larger `minutesPerTick` when catching up
  (e.g. 15-minute steps for anything over an hour).
  *Pro:* bounded work, keeps the real rules. *Con:* granularity artefacts — a chain that
  would have blocked for 5 minutes and recovered will either be missed entirely or block
  for a full 15.

**A is the right call for Helios**, precisely because Helios's economy has the interlocks
OGame's lacks. Cap the replay (e.g. 7 days) and be honest about it in the UI.

**The storage-cap connection.** Offline progress without caps is just "the number went up
while you were away", which is not a loop. With caps, being away means *hitting the
ceiling and wasting time*, which creates the return pressure that makes idle games work,
and gives storage upgrades a reason to exist. OGame's players build storage specifically
so they can sleep. This is the single most valuable interaction between §3.4 and this
section.

**Two multipliers, not one.** OGame universes are configured with a **separate economy
speed and fleet speed**. This is directly relevant: dialling `rateMultiplier` from 1.0 to
1/60 will slow production *and* ship travel by the same factor, and travel is the system
that most needs to stay snappy on mobile — a route that took 20 minutes becomes 20 hours.
Split it before you dial it:

```
GameState.economyRate  // production, population, research
GameState.fleetRate    // travel time, shipyard build time
```

Cheap now, painful to retrofit after balance numbers are set.

---

### 3.6 Fields — the hard build-slot cap

**How OGame does it.** Each planet has a fixed number of **fields** (roughly 90–260,
random on colonisation, biased by orbital position). One building occupies exactly one
field *regardless of its level*. When fields run out, nothing new can be built. The
Terraformer adds fields — and itself costs a field.

This one rule generates most of OGame's strategic texture: it's why planet position
matters, why the Discoverer class's +10% planet size is considered strong, and why
colonising is a decision rather than a formality.

**Why Helios should consider it.** Helios currently has no reason not to build every
chain. A colony-level plot/footprint cap would:

- Make each chain a genuine choice, which is what makes the colony-pool interlocks
  interesting — you feel the shape of an economy you *chose*.
- Give world types (Oceanic / Arid / Ice / Volcanic / Gas Giant) a mechanical identity:
  different plot counts, not just different art.
- Give multi-colony an actual purpose, since specialisation becomes forced rather than
  optional.
- Give the Habitat construction mechanic and the category chips something to compete over.

*Con:* it's a restriction, and restrictions need good UI to not feel arbitrary. It also
interacts with levels (§3.3) — the OGame answer is that levels are free in space, which is
exactly what makes upgrading feel good next to a scarce plot count. That pairing is worth
copying together rather than separately.

---

### 3.7 Cargo, fuel, and the speed slider

Three OGame mechanics that between them turn Helios's fleet from a status display into a
system, and discharge most of the standing rule on display-only ship stats.

**Cargo as an integer.** Every ship has a capacity; a transport carries up to that much,
split however the player chooses. Arrival deposits into the destination's stock. This is
exactly the doc's *cargo delivery* item, and the OGame framing adds one thing: **loading is
a withdrawal**. Sending a freighter should decrement `colonyStock` at launch, not at
arrival. That single rule makes the fleet a real participant in the economy instead of a
free money faucet, and it means an over-ambitious shipment can starve a chain — a good,
diagnosable failure.

**Fuel that occupies cargo.** OGame deducts deuterium at launch and, critically, the fuel
is *carried*, so it eats into the cargo capacity for the trip:

```
Fuel = 1 + round( baseCost × distance / 35000 × (speed/100 + 1)² )
```

*Pro for Helios:* it gives Power Cells (or a dedicated fuel resource) a second consumer,
creates a real range/payload trade-off, and makes long routes cost something. It's also
the cleanest justification for the Power Plant's output existing at all.
*Con:* another authored number per ship role, and it makes route planning arithmetic-heavy
— which on mobile means the UI has to do the math for the player, not present it.

**The speed slider.** OGame lets you fly at 10–100% speed. Flight time and fuel move in
opposite directions:

```
t (seconds) = (10 + (35000 / speedFactor) × √(distance × 10 / shipSpeed)) / universeFleetSpeed
              where speedFactor = 1…10 for 10%…100%
```

Two things here. First, the **slider is the decision** — fast and expensive vs slow and
cheap is a real choice made at dispatch, and it costs one control. Second, note flight
time scales with **√distance**, not distance. Helios currently uses
`travelTimeMinutes / speedMultiplier`, which is linear. The square root means distant
targets are proportionally cheaper in time than near ones, which keeps the late-game map
traversable instead of making far colonies unusable. Worth adopting if world distances
will ever span an order of magnitude; not worth it if they won't.

One more rule worth stealing for free: **a fleet moves at the speed of its slowest ship**.
It's one line and it makes fleet composition matter.

---

### 3.8 Combat — a concrete algorithm for `shields` and `weapons`

The standing rule says everything the ship UI displays must eventually be real. OGame's
combat resolution is the most battle-tested implementation of exactly the three stats
Helios already displays (cargo, shields, weapons), it's fully deterministic given a seed,
and it's roughly sixty lines.

**The algorithm:**

```
for round in 1...6:
    for each unit on both sides (simultaneously):
        target = random enemy unit
        repeat:
            damage = unit.weapons
            if damage > target.shield:
                target.hull -= (damage - target.shield)
                target.shield = 0
            else:
                target.shield -= damage
            if target.hull < 0.7 × target.initialHull:
                // roll every time it's hit, not once per round
                if random() < (1 - target.hull / target.initialHull):
                    target.hull = 0
        while unit.hasRapidFire(against: target) && random() < (r-1)/r
    remove destroyed units
    regenerate shields on survivors
    if either side is empty: break
// after 6 rounds with both sides alive: draw (attacker takes nothing)
```

Three details that carry most of the feel and are easy to miss:

1. **The explosion roll happens per hit, not per round.** A ship at 69% hull taking twenty
   small hits is very likely to die even though its hull barely moves. This is why swarms
   of cheap units beat a few expensive ones more often than raw stats suggest — it's the
   single most important balance property of the system.
2. **Rapidfire is a re-roll, not a damage multiplier.** A unit with rapidfire `r` against a
   target has a `(r-1)/r` chance to immediately fire again at a *new random* target. This
   is what makes composition (and cheap "fodder" units) matter.
3. **Shields regenerate between rounds** for anything still alive, so a shield high enough
   to bounce the enemy's per-shot damage is effectively immortal. Big cheap swarms and
   high-shield ships are natural counters to each other without any rock-paper-scissors
   table.

**Aftermath rules** (all optional, all cheap): 30% of destroyed ships' build cost becomes a
harvestable debris field; 70% of destroyed defensive structures rebuild automatically; the
winner loots up to 50% of the target's stock, limited by surviving cargo capacity.

For a single-player Helios the PvP framing doesn't apply, but the resolver is
target-agnostic — it works identically against a PvE raider event, an expedition ambush, or
a hostile world. Building the resolver is separable from deciding what it fights.

---

### 3.9 Population — OGame's Lifeforms vs the Anno squeeze

Since 2022 OGame has a population system, and it's worth comparing carefully because it's
the closest thing to Helios's ladder, but built on different assumptions.

| | Helios | OGame Lifeforms |
|---|---|---|
| Structure | 5 rungs, distribution across tiers | 3 tiers, upgraded via specific buildings |
| Cap | Per-tier `capacity` (habitats planned) | Housing buildings set max population |
| Consumption | Basic + luxury needs per resource | A single **food** resource |
| Failure | Basic unmet → fast attrition; luxury unmet → unhappy, blocks promotion | Food deficit → population declines |
| What population *does* | Consumes; will staff chains (planned); Ascendants make research points | Gates lifeform tech slots and building levels |
| Mobility | Colonists implicitly fixed | Population **cannot** be transported; food **can** |
| Tier drain | Planned: promoting drains the lower tier's workforce | **None** — no squeeze |

**What's worth taking — two rules only:**

1. **Population as a gate, not just a consumer.** In OGame, population's primary function
   is unlocking things: hit a population threshold and a research slot opens. Helios has a
   partial version (Ascendants generate research points) but no thresholds. Gating
   `ResearchProject` availability on tier population would make the ladder feel like
   progress rather than upkeep, and it would give the currently-inert research states a
   reason to unlock over time. This composes well with the workforce squeeze rather than
   competing with it: workforce is the *cost* of population, gating is the *reward*.

2. **People stay, goods move.** OGame's rule that population is non-transportable while
   food is transportable is a clean answer to a question Helios will hit at multi-colony:
   can you ship colonists? Saying no forces each colony to grow its own society and gives
   trade routes their purpose — you ship the *needs*, not the *needers*. It also protects
   the tier squeeze from being trivially solved by relocating people.

**What not to take:** OGame's population is fundamentally a resource with a cap, not a
society. Helios's happiness/promotion/attrition model is more interesting and is the right
call for a colony game. And OGame deliberately has no tier-drain squeeze — its tiers are
strictly better, so there's no reason not to upgrade everyone. Helios's planned rule (a
promoted colonist *stops* providing the lower tier's workforce) is the more interesting
design and is the thing that makes the ladder a system instead of a track. Keep it.

---

### 3.10 Multi-colony and making world types mechanical

**How OGame does it.** Colony count is gated by Astrophysics research (cost roughly
quadruples per level, hard cap around nine planets). Where you colonise matters
mechanically in two ways: **orbital position** biases the number of fields you get, and
**temperature** directly scales deuterium output — the formula's `(1.44 − 0.004·T_max)`
term means cold outer planets produce several times the deuterium of hot inner ones, while
hot planets get more solar energy.

The result is that no planet is good at everything, and the empire becomes a portfolio.

**The transfer for Helios.** The five world types are currently flavour. Making them
production modifiers is nearly free and immediately makes the deferred world-switcher
worth building:

| World | Plausible modifier shape |
|---|---|
| Ice | Ice Harvester output ×2, Hydroponics penalised |
| Volcanic | Ore and energy bonus, life-support penalty |
| Oceanic | Water and food bonus, ore scarce |
| Arid | Solar/energy bonus, water heavily penalised |
| Gas Giant | Fuel/gas extraction only, no surface plots |

Note this pairs directly with §3.6 — plot count *and* per-resource multipliers are the two
knobs OGame uses, and together they're enough to make every colonisation choice a real
one. Neither works alone: multipliers without a plot cap just means "build everything
anyway, slightly better here."

**Gating.** OGame's quadrupling Astrophysics cost is the standard shape for a hard
expansion gate. It works because expansion is the strongest possible reward, so it needs
the steepest possible curve. If Helios gates colonies on research, price them like OGame
does — aggressively — rather than like a normal tech.

---

### 3.11 Research: what to settle before multi-colony

OGame's research is empire-wide: cost roughly doubles per level, time scales with cost and
divides by Research Lab level, and completed techs apply to every planet at once. Lifeform
techs are the same — cumulative across colonies. But lifeform *buildings* are strictly
local to the planet they're on.

That global/local split is the useful part, and it's a decision Helios has to make anyway
before the world-switcher lands:

- **Techs global, buildings local** (OGame's answer). Research feels like empire progress;
  colonies differ by what's physically built. Simple to reason about, and it means research
  never has to be duplicated.
- **Everything local.** Each colony researches independently. More texture, much more
  management, and on mobile it's probably too much.
- **Split by category.** `ResearchCategory` already exists as a chip filter with no
  mechanical meaning — it could become the axis: some categories empire-wide, others
  per-colony. This gives the chips a job, same as §3.3 Option B does for the colony chips.

The cost curve matters too. OGame's research doubling (~`2^L`) is steeper than its building
cost curve (`1.5^L`) — deliberately, because research bonuses apply everywhere at once and
so compound harder. If Helios adds research multipliers, price them above building levels.

---

### 3.12 Points — the cheapest legibility win here

OGame's score is `total resources ever invested ÷ 1000`, split into economy / research /
military / defence sub-scores. It's crude, it's gameable, and it's been the backbone of the
game's motivation for twenty-four years, because it answers "am I doing well?" in one
number and lets you compare yourself across time.

Helios has no such number. A colony rating derived from resources invested + population +
research completed is a few lines, needs no new systems, and gives `MainColonyView` a hero
stat that isn't a raw resource count. The sub-score split is worth copying too — it tells
the player *what kind* of colony they've built, which is the read that makes the number
interesting rather than just large.

---

### 3.13 Trade — a genuine fork

OGame has **no standing trade routes**. Every movement is a discrete mission the player
launches and that returns. Player-to-player trade is manual negotiation at a customary
3 metal : 2 crystal : 1 deuterium; the dark-matter merchant converts between resources at a
fixed rate for anyone who'd rather pay than wait.

Anno has standing routes. Helios's `.docked` status was reserved for them.

This is a real fork and it should be decided explicitly, because the two produce different
games:

- **Standing routes (Anno):** set up once, income becomes passive, the skill is in designing
  the network. Fits a colony-builder. Activates `.docked`. Risk: once configured, the fleet
  screen becomes read-only and ships stop being interesting.
- **Discrete missions (OGame):** every dispatch is a decision, ships are always "yours to
  send", and the fleet stays engaging. Fits mobile check-in play very well — a session
  becomes "collect the returns, send the next wave." Risk: it's a chore loop if the payload
  is boring, and `.docked` never activates and should be deleted.
- **Hybrid:** routes for bulk logistics, manual missions for expeditions and one-offs.
  Both systems, both sets of bugs.

Worth noting: the dormant-case warning in the design doc's gotchas applies squarely here.
If discrete missions win, `.docked` should be removed rather than left to rot further.

---

### 3.14 Risk, and the emergent-mechanic lesson

Helios has no way to lose anything. OGame's entire tension comes from the fact that your
stock sits on a planet other people can reach, and from the resulting **fleet save** ritual
— launching your fleet on a long pointless flight before bed, because fleets in transit
cannot be attacked. Nobody designed fleet saving. It emerged from one rule interacting with
one other rule, and it's now the defining behaviour of the entire playerbase.

That's the transferable lesson rather than the mechanic: Helios's colony-pool decision
already produced emergent chain interlinking with no dependency graph, which is the same
kind of win. The systems most worth adding are the ones that *interact* with what exists,
not the ones that sit beside it. By that test, §3.1 (energy throttle), §3.6 (plot cap), and
§3.7 (loading is a withdrawal) score highest — each one changes the meaning of systems
already built. Combat and trade routes score lowest, because they'd mostly run in parallel
to the economy.

If loss is ever wanted in single-player, the OGame-shaped version is: stock above storage
capacity is vulnerable to a periodic hazard (solar flare, raider, containment failure).
That makes storage upgrades protective as well as productive, and it makes offline absence
carry actual risk — which is the strongest possible reason to open the app.

---

## 4. What to leave behind

- **Dark Matter, officers, classes.** Monetisation and account-level modifiers. Classes
  (Collector/General/Discoverer) are interesting as an idea — a permanent playstyle
  commitment that reshapes the economy — but they're built for a competitive server
  economy, and in single-player they reduce to a difficulty selector.
- **Flat, chainless production.** OGame's mines produce from nothing. Helios's chains are
  strictly more interesting; don't let OGame's simplicity tempt you toward flattening.
- **PvP, alliances, espionage, ACS.** Whole different game.
- **Points-as-target.** OGame's score doubles as a raiding target indicator, which distorts
  play (people deliberately stay small). In single-player, take the score, skip that.
- **Twelve-hour build times.** OGame's pacing assumes a browser tab and a multi-year server.
  Adopt the exponential *shapes*, not the absolute durations.
- **The 1% shield bounce rule and other deep combat minutiae.** The core loop in §3.8 is
  enough; the fine print exists because a competitive economy demanded it.

---

## 5. Priority, mapped onto the existing roadmap

Ordered by (value to Helios) × (fit with what's already built), with the doc's own next-up
items woven in:

1. **Split `rateMultiplier` into economy and fleet rates** — do this *before* the honest-pacing
   work, not after. Minutes of work now, painful later. (§3.5)
2. **Energy as a production factor** — closes the "energy as universal requirement" item and
   the "scarcity is crude" item with one mechanic. Highest value-per-line in this report. (§3.1)
3. **Output % per chain** — nearly free once (2) lands; converts the array-order bug into a
   feature. (§3.2)
4. **Offline catch-up by tick replay**, capped — the roadmap item, with the recommendation
   to replay rather than solve. (§3.5)
5. **Loading is a withdrawal, arrival is a deposit** — completes the cargo-delivery item and
   makes `cargoCapacity` real, discharging part of the standing rule. (§3.7)
6. **Levels on something** — the missing vertical axis. Decide between chain-levels and
   building-levels; building-levels composes better with the deferred construction and
   habitat work. (§3.3)
7. **Plot cap per colony + world-type modifiers** — turns world types and the Habitat chip
   from cosmetic into mechanical, and gives multi-colony a reason to exist. (§3.6, §3.10)
8. **Storage as a levelled building** — makes offline absence meaningful instead of free.
   Pairs with (4) and (6). (§3.4)
9. **Colony score** — cheap, and it gives the crowded `MainColonyView` a hero number worth
   the space it takes. (§3.12)
10. **Population gates on research availability** — makes the ladder rewarding, complements
    rather than duplicates the workforce squeeze. (§3.9)
11. **Speed slider + fuel** — good decisions per dispatch, but wants the fleet↔economy loop
    (5) closed first. (§3.7)
12. **Trade routes vs discrete missions** — decide the fork before building either; resolve
    `.docked`'s fate at the same time. (§3.13)
13. **Combat resolver** — highest effort, most separable, and the only item here that doesn't
    change the meaning of an existing system. Worth doing eventually because of the standing
    rule on `shields`/`weapons`, but last. (§3.8)

The workforce item from the roadmap isn't in this list because OGame has nothing to teach
about it — no tier squeeze exists there. It remains Anno's contribution and should be
designed on its own terms. Note only that it will interact hard with §3.1: a chain that is
both under-staffed and under-powered needs a defined combination rule (multiply the two
factors, or take the minimum — multiply is harsher and more legible).

---

## 6. Open questions this raises

1. Does scarcity throttle everything, or just energy? (§3.1 A/B/C) — this determines whether
   `ChainStatus` stays a three-case enum.
2. Do levels live on chains or on buildings? — this determines whether the deferred
   construction mechanic is a prerequisite or a consequence.
3. Is there a plot cap? — this is the difference between "build everything" and "build a
   colony", and it's much cheaper to add now than after chain counts grow.
4. Trade routes or discrete missions? — and therefore, does `.docked` live or die?
5. Can colonists be shipped between colonies? — OGame says no; that answer protects the
   workforce squeeze.
6. Is there ever loss? — the answer determines whether storage is a convenience or a
   defence.

---

## Appendix — OGame formula reference

Community-derived, verified against in-game values. Universe speed multipliers apply to
production and build times; a separate fleet-speed multiplier applies to travel.

**Production (per hour, per planet)**
```
Metal      = 30 · L · 1.1^L
Crystal    = 20 · L · 1.1^L
Deuterium  = 10 · L · 1.1^L · (1.44 − 0.004 · T_max)
Solar      = 20 · L · 1.1^L
Fusion     = 30 · L · (1.05 + 0.01 · EnergyTech)^L
Mine draw  = ⌈10 · L · 1.1^L⌉        (deuterium synthesiser draws ×2)
Factor     = min(1, energyProduced / energyRequired)   → multiplies all output
```

**Costs and time**
```
Building cost      ≈ base · 1.5^(L−1)
Research cost      ≈ base · 2^(L−1)
Storage capacity   = 5000 · ⌊2.5 · e^(20L/33)⌋
Build time (hrs)   = (metal + crystal) / (2500 · (1 + Robotics) · speed · 2^Nanite)
Ship time (hrs)    = structuralIntegrity / (2500 · (1 + Shipyard) · speed · 2^Nanite)
Research time(hrs) = (metal + crystal) / (1000 · (1 + Lab) · speed)
Mine payback (hrs) = (3 / (4L)) · (15/11)^L
```

**Fleet**
```
Flight time (s) = (10 + (35000 / speedFactor) · √(distance · 10 / shipSpeed)) / fleetSpeed
                  speedFactor = 1…10  (10%…100%)
Fuel            = 1 + round(baseCost · distance / 35000 · (speed/100 + 1)²)
Expedition slots= ⌊√(Astrophysics level)⌋
Expedition pts  = Σ (metal + crystal cost) · 5 / 1000    per ship
```

**Combat**
```
Rounds          ≤ 6, simultaneous, random targeting
Damage          → shield first, remainder → hull
Explosion roll  → if hull < 70% of initial: P(destroy) = 1 − hull/initialHull, per hit
Rapidfire r     → P(fire again at new random target) = (r−1)/r
Shields         → regenerate between rounds for survivors
Debris          = 30% of destroyed ships' metal + crystal
Defence rebuild = 70% of destroyed structures
Loot            = up to 50% of target's stock, capped by surviving cargo
Moon chance     = debrisTotal / 100000, capped at 20%
Points          = total resources invested / 1000
```
