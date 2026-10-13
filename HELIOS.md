# HELIOS

**The single source of truth.** Premise, systems, architecture, plan, decisions.

| | |
|---|---|
| **Status** | Authoritative. Nothing else in this repo overrides it. |
| **Last reconciled** | 13 October 2026, after Phase 2. Every balance figure in Appendix C re-measured against the live allocator during that phase — the 28 Aug figures were wrong and are corrected there. |
| **Supersedes** | `HELIOS_DESIGN.md`, `HELIOS_ROADMAP.md`, `HELIOS_WORLD.md` — all three now stubs pointing here. Their full text is in git history. |
| **Reference, not authority** | `OGAME_COMPARISON.md` (research input), `sources/` (Anno 1800 library), `AUDIT-2026-08-28.md` in the Claude project (point-in-time snapshot) |

> **Rule for this document.** Design decisions, current state, and the plan live
> here and only here. Research inputs stay where they are and remain inputs —
> when a conclusion is drawn from one, the conclusion is recorded here and the
> source is cited. If this document and any other disagree, this one is right
> and the other one is stale.

---

## Contents

- **Part I — The Game** — §1 premise · §2 principles · §3 core loop · §4 the Empire · §5 the Ascendant Dividend · §6 the long arc · §7 names
- **Part II — Systems as designed** — §8 production · §9 energy · §10 population · §11 fleet · §12 research · §13 planned systems
- **Part III — The build as it is** — §14 architecture · §15 structure · §16 visual language · §17 verified inventory
- **Part IV — Known issues** — §18
- **Part V — The plan** — §19 phases · §20 open questions
- **Part VI — Decision log** — §21
- **Part VII — Working method & gotchas** — §22 · §23
- **Appendices** — A: OGame transfers · B: document map · C: simulated balance baseline

---
---

# Part I — The Game

## 1. Premise

You are the newly appointed **Administrator** of a frontier sector of an
intergalactic empire ⚑.

You did not choose this posting. The sector lapsed — its previous administration
failed, and the Empire's survey data has been out of date for long enough that
parts of it are simply marked *unmapped*. You have been given what the Empire
considers sufficient: one functioning colony, two ships, a starting balance, and
a quota.

Nobody is coming to help. Nobody is coming to stop you either.

**Genre:** a space-colony strategy game for iOS, deliberately an **Anno–OGame
hybrid** shifting toward management/administration. Anno 1800 is the systemic
ancestor; OGame contributes specific mechanisms. All terminology is original.

### Why *Survivors*

The colonist ladder begins at **Survivors**, and that word does work.

The sector was administered before, and that administration failed. The records
are thin and the Empire is not forthcoming. The people at Kepler Outpost-7 are
what remained: not colonists sent to build something, but people who stayed
alive through something.

This makes the existing seed state diegetic rather than arbitrary:

- 248 Survivors and zero Settlers — nobody has been promoted in a long time
- A Tool Fab standing idle with zero Refined Alloy — the smelter stopped
- Ships docked at Vesta rather than home
- "Unmapped Sector 12" and "Deep Space Anomaly" — the survey lapsed with the
  administration

It also gives the ladder an emotional shape: Survivors → Settlers is not a number
going up, it's the moment the colony stops enduring and starts *building* —
exactly where luxuries and happiness come online.

**Open:** how much of the predecessor's story to tell. Instinct: *very little*.
A few artefacts, an unexplained blocked chain, a name on a plaque. The Empire's
incuriosity about it is more characterful than an explanation.

---

## 2. Guiding principles

**Take OGame's mechanisms; keep Anno's centre of gravity.** Anno is a *flow*
game — value lives in throughput, interlocks, and the tier squeeze. OGame is a
*stock-and-exponent* game — value lives in accumulated numbers. OGame's three
genuine gifts (production factor, offline catch-up, levels) are all stock-side
mechanics; bolted on carelessly they would pull Helios toward "watch numbers grow
while away," hollowing out the flow game. **Levels and plots exist to make
choices scarce, not numbers big.**

**Offline accumulates; sessions decide.** At honest 1/60 pacing, eight hours away
yields ~480 game-minutes of output while a five-minute session yields five.
Offline will always dwarf active play — so active play must not be *about*
output. Absence generates materials. Presence is where the player retasks chains,
sets output percentages, upgrades buildings, and dispatches ships. This is the
north star for every pacing number.

**Endless.** No win condition. Long-term motivation is the standing ladder
(§4, §6) and eventually asynchronous multiplayer (§19, Phase 8).

**Play pattern:** both. Short sessions, offline continuity between them.

**Long planning windows are the reward.** What a good administrator earns is not
a bigger number — it's being left alone long enough to build something. See §4.

---

## 3. The core loop, in fiction

The Empire wants **specific things, in specific amounts**. It does not much care
how you produce them.

At intervals it assesses your sector and issues a **Quota** ⚑: a manifest of
named goods and quantities it expects to leave your docks. Meet it and you are
paid a stipend, and left alone. Meet it consistently and doors open — better
writs, better prices, longer intervals between demands. Miss it and the leash
shortens.

Everything else — chains, colonists, ships, worlds — is how you find the slack to
grow while still paying what you owe.

**That is the whole game:** the Empire ratchets its expectations against your
assessed capacity, so standing still is a slow loss. You expand not to win, but
to stay ahead of the assessment.

---

## 4. The Empire

Vast, old, and procedural. Not evil — it simply has forms, precedents, and four
thousand other sectors to think about. Your sector is a line item in a ledger
held somewhere you will never visit.

**Tone:** the pressure in Helios is *administrative*, not villainous. No one is
out to get you. The quota arrives on time whether or not your harvesters are
running.

**Technical consequence:** *the Empire keeps the ledger* is the in-fiction reason
the multiplayer architecture is server-authoritative (§19 Phase 8). The
constraint and the story are the same sentence.

### 4.1 Standing — posture is dynamic

**Standing** ⚑ measures **reliability**: what you delivered against what was
demanded, over time. Not size. Not wealth. A modest sector that always delivers
has excellent standing; a sprawling one that misses quarters does not.

| Band | Posture | Cadence | What changes |
|---|---|---|---|
| **Patron** | Invested | Rare, large, announced far ahead | Subsidised writs, bonus stipend, early archive access, hazard warnings |
| **Favourable** | Pleased | Infrequent | Reduced writ costs, gentler assessment growth |
| **Indifferent** *(start)* | Procedural | Regular | Standard rates. The default state of the universe. |
| **Scrutinised** | Displeased | Frequent, small | Writ costs rise, stipend falls, short notice |
| **Receivership** | Extractive | Constant, small | The Empire collects **at the dock** rather than paying |

You begin at **Indifferent** — neither reward nor punishment, simply what the
Empire feels about a sector it has not thought about.

**Three rules that keep this from breaking:**

1. **Failure never raises the *rate*.** Falling standing shortens the interval
   and shrinks each shipment — it does not increase total demand. The Empire is
   checking on you more often, not squeezing harder. What you lose is *planning
   horizon and attention*, which is punishing without being an economic death
   spiral. Otherwise the loop is self-reinforcing exactly like a brownout
   throttling the power plant that would end it (§9).
2. **Bands are sticky.** Hysteresis on thresholds; movement measured over several
   cycles, so standing doesn't flicker on one bad shipment. A slope, not a switch.
3. **Receivership has a floor.** Unpleasant and slow to climb out of, but it does
   not take population, does not take buildings, and does not cascade. Consistent
   with the bounded-loss decision (§21).

**Multiplayer warning.** OGame's public points double as a raiding-target
indicator and distort play — people deliberately stay small (`OGAME_COMPARISON.md`
§4). Standing will eventually be visible to other administrators. If standing
*also* drove quota, staying small would be rewarded twice over. Keep the three
inputs separate:

- **Quota** scales with *assessed capacity* (what you've built)
- **Standing** scales with *reliability* (delivered ÷ demanded)
- **Raid attractiveness** scales with *stockpile* (what's in your stores)

Then "stay modest, stay reliable, keep stores low" is a coherent playstyle with
real trade-offs rather than an exploit.

### 4.2 The Quota — the demand sink

**Named goods, not bulk tonnage.** A quota is a manifest: *40 Alloy Tools, 120
Ration Bars, 60 Power Cells.*

This is the single most important decision in Part I, because a manifest does
something a tonnage cannot: it **forces retasking**. Your chains are tuned for
what your colonists need; the manifest asks for something else. Closing that gap
— reallocating output percentages, rebalancing workforce, deciding what to let
run dry — is the decision the "presence decides" north star was waiting for.

**It is also the engine of expansion.** When the manifest names a good your
sector cannot produce, you have to go get it: a new chain, a new writ, or a new
colony on a world type that supports it. Quota is what makes colonising the
sector a *need* rather than an option.

**Announced a cycle ahead.** The next manifest publishes when the current one
settles, so you always have one full interval to retool. A quota you cannot see
coming is not a decision, it's a dice roll. At Patron standing the visibility
extends further — part of what the band is worth.

**Mechanically:** quota goods are withdrawn from stores and **leave the sector**.
This is the sink the economy currently lacks (§18 S1). With it there is permanent
downward pressure on stock, chains keep running, and storage becomes a *buffer
against the quota* rather than a ceiling everything parks against. It also makes
the fleet matter — quota is shipped, so hauling capacity is a real constraint,
which is what "loading is a withdrawal" was always for (§11).

### A quota is a ledger, not a snapshot ▲

**Deliveries accumulate against the quota across the interval. The Empire does
not take a snapshot of your stores at the deadline.**

This was tested rather than assumed (Appendix C), and snapshot settlement fails
badly. Because a snapshot can only take what you are *holding*, quota size is
silently capped by storage capacity rather than by production. At a 960-minute
interval the power-cell demand is **19× everything the colony can physically
hold** — unmeetable at any level of industry. Worse, the interval lengthens as
standing improves, so under snapshot settlement *the better you play, the more
impossible the quota becomes*. That is the standing spiral reappearing through
a side door.

Ledger delivery removes it completely. Measured fill rate across intervals of
60, 240, 960 and 2,880 minutes: **0.59, 0.59, 0.60, 0.60** — interval has no
economic effect at all. That is exactly what §4.1 needs: cadence can be a pure
attention-and-planning mechanic with no hidden economic consequence.

It also gives the fleet a real job. You deliver in several trips across the
interval rather than one lump, so hauling capacity and trip timing matter, and
storage becomes a buffer for *timing* rather than a ceiling on ambition.

### Sizing ▲

Quota per good is set from that good's **measured export capacity** — production
net of colonist consumption — times the interval, times a load factor.

**Load 1.0 is the target.** Re-measured after Phase 2, against corrected
capacity figures (Appendix C):

| Load | Settled fill | Stores settle at | Population |
|---|---|---|---|
| 0.5 | 1.000 | 98% — still saturated | 450 |
| 0.75 | 1.000 | 95% — still saturated | 450 |
| **1.0** | **1.000** | **29% mean** | **450** |
| 1.2 | 0.783 | 17% | 439 — colonists dying |
| 3.0 | 0.489 | 56% | 229 — colony collapsing |

Below ~0.75 the quota is too small to be a sink and the colony stays saturated.
Above ~1.2 the quota starts eating the colony. **The usable band is narrow**, and
that is the single most important balance fact in the game.

### Load 1.0 is meetable with no effort at all, and that is now the open question ▲

With capacity measured correctly, a quota sized at load 1.0 asks for exactly
what the colony can spare — so an untouched colony fills it completely, every
cycle, for ever. Measured: fill 1.000 cycle after cycle, Settler happiness
1.000, and Standing climbing to Patron **in two settlements** with no way back
down. Every mechanism in §4.1 and §4.3 works and sits inert, because there is
no way to fail.

The squeeze this document describes — "settlers sit at 0.86 happiness because
the Empire is taking their Alloy Tools" — was real, but it came from the Phase 1a
debug sink draining ~2% faster than the colony could produce (53% faster on
Ration Bars), i.e. from an *accidental* load of about 1.02. It does not exist at
1.00.

Since fill is approximately `min(1, 1/load)`, tension and reliability are a
direct trade: at 1.1 fill is 0.824 and the band oscillates
Indifferent/Favourable; at 1.2 it is 0.783 and oscillates
Scrutinised/Indifferent. **Deliberately left at 1.0 leaving Phase 2**, because
the honest fix is not a load number — it is the second sink (§20, Phase 5).

### Colonists eat first, and the Empire cannot take their food ▲

A hard floor reserves a fraction of storage (30% in testing) on basic-need goods
— oxygen, rations, water — which quota may never draw below. Without it, high
quota loads kill the colony outright: at load 3.0, population ends at 192 with
the reserve and **90** without; at load 4.0, 89 with and **zero** without.

Note the reserve protects *basic* needs only. Luxuries stay contested on purpose:
at load 1.0 the settlers sit at **0.86 happiness** because the Empire is taking
the Alloy Tools they want. That blocks promotion and is exactly the intended
squeeze — the Empire's demand competing with your colonists' comfort, with the
player holding the output-% lever that resolves it.

### 4.3 Commissions — the optional half

Alongside the mandatory quota, the Empire occasionally posts **Commissions** ⚑:
optional contracts you may take or ignore.

- Opting in and delivering earns **Favour** and repairs Standing
- Opting in and failing costs more than never opting in at all
- Ignoring them is always safe, and always leaves value on the table

Commissions are the reconciliation path — the way out of Scrutinised is to
volunteer for something and deliver it. They're also where variety lives: a rush
order, a relief shipment to a neighbouring sector, a survey contract, a one-off
demand for something exotic.

Because they're opt-in, they can be *harder* than quotas without being unfair.
That makes them the right place for genuine difficulty spikes.

### 4.4 Favour and Dispensations — the light RPG layer

**Favour** ⚑ is a spendable currency, distinct from Standing.

| | Standing | Favour |
|---|---|---|
| What it is | A rating | A currency |
| Earned by | Reliability over time | Commissions + hosting Ascendants |
| Spent | Never — it's a measure | On Dispensations |
| Effect | Sets Empire posture and cadence | Buys permanent perks |

**Dispensations** ⚑ are a small set of permanent, meaningful modifiers bought
with Favour. Deliberately *not* a skill tree — a short list of real choices, in
the spirit of Anno's specialists rather than an RPG talent grid. Sketches:

- *Standing Survey Rights* — new destinations reveal one tier further out
- *Preferential Berth* — quota counts as delivered on loading, not arrival
- *Labour Exemption* — one building class runs at reduced workforce
- *Archive Clearance* — one research category permanently unlocked
- *Grace Period* — one missed quota per interval doesn't count against Standing

**Guideline:** a Dispensation should change *how you play*, not multiply a number.
If it can be expressed as "+10% to X," it belongs in research instead.

### 4.5 Writs — authorisation, not currency

You are an administrator, not an emperor. You cannot simply build.

A **Writ** ⚑ authorises: a plot, a new colony claim, a class of building, a tier
of habitat. Writs cost credits; availability and price depend on Standing.

This is the fiction for the plot cap and for levels (§13, §19 Phase 4). A cap
that exists because *permission* is scarce reads far better than an arbitrary
number, and it explains why the constraint loosens as you rise. "The Empire's
writ" is also the natural phrase for how far its authority reaches — see §6.

### 4.6 The Archive — research

Your engineers do the work, but the Empire holds the blueprints. Research points
are generated locally; **unlocking** a project requires points *and* sufficient
Standing.

This gives Standing teeth in a second system, and gives the currently inert
research screen (§18 S10) a reason to have a locked state at all.

### 4.7 The three currencies

| Currency | Source | Sink |
|---|---|---|
| **Credits** | Stipend for met quotas, scaled by Standing | Writs, ships |
| **Favour** | Commissions, Ascendant dividend | Dispensations |
| **Research Points** | Generated locally by Ascendants | Archive projects (gated on Standing) |

No source feeds two currencies; no currency has two sinks. **Worth protecting as
the design grows.**

### 4.8 Cadence and the real-time clock

Quota intervals are **real-time**, and their length is set by Standing (§4.1).

**Clarification, Phase 2 ▲:** cadence is expressed in **game-minutes**, and
becomes real-world time for free when Phase 4 dials `economyRate` to 1/60. A
deadline is an absolute tick count compared against `GameState.tickCount`, never
a `Date` — `tick()` has to stay pure and clock-free or Phase 4's replay and
Phase 9's reconciliation both break, and the Phase 1.5 `tickIsDeterministic`
test stands guard over it. The intent below is unchanged; this is how it gets
there without building it twice.

Two consequences to be explicit about:

**Persistence becomes a hard prerequisite, not a Phase 3 nicety.** A real-time
deadline is meaningless without a save file and offline catch-up. §18 S4 already
argued persistence should come forward; this decision settles it.

**It is the first thing in Helios tied to the wall clock.** Everything else is
game-time. When a player is away longer than an interval, the ledger (§4.2) keeps
accruing deliveries during catch-up replay and the quota settles at its deadline
with whatever accumulated, shortfall recorded. Absence therefore costs you the
*optimisation* — a present player retasks chains to close the gap — but never
strands you behind an unmeetable snapshot.

**Interval length has no economic effect.** Verified across 60 → 2,880 minute
intervals (Appendix C). This is what makes the band system in §4.1 safe: cadence
changes how much planning room you have and how often you must attend, and
nothing else.

---

## 5. The Ascendant Dividend

**Ascendants are citizens of the core who happen to reside in your colony.**

They have been elevated out of your sector's society and into the Empire's. They
live in your habitats, eat your luxuries, and are no longer yours. They provide
**no workforce** — already true in code (`ColonistTier.providesWorkforce`), and
now it has a reason.

What they provide is standing with the core: **Favour**, and the research points
the UI already credits to them.

### The trade

> **Your success is measured in the people you can no longer use.**

Every promotion to Ascendant is a worker deleted from your economy in exchange
for privilege. This is the Anno tier squeeze — the piece OGame cannot teach —
made diegetic and dramatic rather than merely arithmetic.

### The lever already exists

Promotion is gated on **free capacity in the tier above**
(`Population.applyPromotions`). So you never demote anyone and never manage
individuals — you decide **how much Ascendant housing to authorise**. That makes
an Ascendant habitat the most expensive Writ in the game, and building one a
deliberate, irreversible-in-practice trade of labour for favour. No new mechanic
required.

### The Ascendant trap — intended, not a bug

Over-commit and you get a colony full of expensive residents who consume your
best goods, produce nothing, and leave your chains understaffed — while the quota
still arrives. That failure should be *reachable*, legible, and slow enough to
see coming.

### Why it stays live instead of settling into a fixed ratio

Because the quota names **specific goods**. A changing manifest changes which
chains you need staffed, which changes how much labour you can afford to elevate.
§4.2 is what keeps §5 from becoming a solved equation.

### Consequence for tiers 3–5

This gives the placeholder tiers a shape:

- **Engineers** — the skilled workforce. High output value, high luxury demand.
- **Synthesists** — the transitional rung. Still yours, but expensive.
- **Ascendant** — no longer yours. Pure cost; pays in Favour and Research.

The ladder stops being "bigger numbers as you climb" and becomes a curve: labour
value peaks in the middle and goes to zero at the top.

---

## 6. The long arc: the writ recedes

There is no win condition. But there is a direction.

At the top of the standing ladder, the Empire's involvement becomes nominal.
Intervals stretch. Quota becomes a formality against your actual output. Writs
are granted as a matter of course. Inspections stop. You are not independent —
nobody declares independence — but the Empire's writ has quietly receded to a
line in a ledger, and the sector is yours in every way that matters day to day.

The fantasy: **not conquest, not victory — autonomy through competence.** It fits
an endless game because it never arrives as an event. It accumulates.

---

## 7. Names to settle ⚑

| Concept | Candidates |
|---|---|
| The empire | *The Concord* · *The Compact* · *The Directorate* · *The Ascendancy* |
| The mandatory demand | *Quota* (plain, Anno-ish) · *The Levy* · *Assessment* · *Tithe* |
| The optional contract | *Commission* · *Charter* · *Requisition* |
| Reliability rating | *Standing* · *Rating* · *Assessment* |
| Spendable prestige | *Favour* · *Merit* · *Consideration* |
| Perks | *Dispensation* · *Concession* · *Privilege* |
| Permits | *Writ* · *Charter* · *Licence* |
| Your title | *Administrator* · *Prefect* · *Steward* |

**On *The Ascendancy*:** collides with the top colonist tier — productively. If
Ascendants are colonists who have become citizens of the core, the shared root is
the point, and it explains in one word why they provide no workforce. Cost:
"Ascendancy / Ascendant" in one sentence may read as muddled. Test aloud before
committing.

---
---

# Part II — Systems as designed

## 8. Production — a colony-wide pool

One stock per resource type per colony. Chains draw from it and deposit into it,
so interlinking is **emergent** rather than declared: no dependency graph, no link
management, no evaluation ordering.

| Type | Role |
|---|---|
| `Resource` | Static registry. Slug ids (`"refined-alloy"`), per-resource capacity. |
| `ColonyStock` | Value type. `deposit` / `withdraw` (all-or-nothing) / `drain` (clamped, for proportional allocation). |
| `ChainFlow` | A *requirement* (`resourceID` + `ratePerMin`), not a store. Resolves name/icon/capacity from the registry. |
| `ChainDetail` | A production chain. `applyTick` is the `SimulationCore` seam. |
| `ChainStatus` | `{ running, limited(LimitReason), stalled, paused }` |
| `LimitReason` | `{ input(Resource.ID), power, workforce }` — only the single *binding* constraint is reported |
| `ProductionAllocator` | Colony-wide two-phase proportional allocation. Pure and portable. |

Rates are stored as **positive magnitudes**; the `+`/`-` display sign derives from
input-vs-output position.

### The allocation algorithm (as built)

Two phases, so the energy grid resolves without circularity:

1. **Output headroom** computed per chain. Energy producers have no output store,
   so they are never capped here.
2. **Phase A** — energy producers resolve first, exempt from the grid factor.
3. **Grid** — supply from producers' *achieved* throughput; demand from
   consumers' output-capped desire.
4. **Phase B** — consumers resolve against the grid factor and proportional
   inputs.

Producers therefore also get first call on shared inputs. Deliberate: keeping the
lights on takes precedence.

Within a phase: aggregate demand per resource, compute `ratio = stock ÷ wanted`,
then each chain runs at `min(outputCap, energyFactor) × tightest input ratio`.
Status reports only the tightest constraint, so the UI names one actionable thing.

### The ten-chain seed network

```
Ice Harvester   ─┐
Ore Extractor   ─┤ extractors, no material inputs
Power Plant     ─┘ (energy only — no output store, hence no self-throttle)
                   ├─→ Water Reclaimer ──→ Hydroponics Bay ──→ Ration Bar Synth
                   ├─→ Oxygen Recycler
                   └─→ Alloy Smelter ──┬─→ Alloy Tool Fab
                                       └─→ Cell Factory
```

**Note the alloy bottleneck.** Smelter supplies 7 Refined Alloy/min; Tool Fab and
Cell Factory demand 5 + 3 = 8/min. Both consumers sit permanently at ~87.5% until
storage saturation masks it. This is currently unintentional — see §18 S1.

## 9. Energy — a live balance, never stored

Energy is consumed the instant it is made. Per colony:

- `gridSupply` / `gridDemand` refreshed each tick
- `gridFactor = min(1, supply ÷ demand)`
- `gridUtilisationPercent` — how much of generation is being drawn; can exceed
  100% under brownout

**Producers are exempt from their own throttle.** This is the critical rule:
energy producers are themselves chains, so without the exemption a brownout
throttles the plant and deepens itself, and the colony can never recover. Solved
by resolving producers in Phase A at factor 1.

Model taken wholesale from OGame's production factor (`OGAME_COMPARISON.md` §3.1),
which is exactly the design already intended and arrives with the throttle
included.

## 10. Population — a distribution, not a pool

Five rungs, modelled as `[TierPopulation]`. A colony is a mixed society.

```
Survivors → Settlers → Engineers → Synthesists → Ascendant
```

| Type | Role |
|---|---|
| `ColonistTier` | Basic needs, luxury needs, `next`, `providesWorkforce`. |
| `PopulationNeed` | `resourceID` + `per100PerMin`. |
| `TierPopulation` | `count`, `capacity`, `happiness`, `basicSatisfaction`. |
| `Population` | The distribution, tuning, tick and promotion logic. |

| Tier | Basic | Luxury |
|---|---|---|
| Survivors | Oxygen 2.0, Ration Bars 1.2 | — |
| Settlers | Oxygen 2.5, Ration Bars 1.5, Water 1.0 | Alloy Tools 0.5 |
| Engineers / Synthesists / Ascendant | *placeholder* — shape given in §5 | *placeholder* |

Water is basic (survival), Alloy Tools luxury (quality of life) — split
deliberately so the happiness mechanic is exercised.

**Allocation mirrors production:** aggregate demand across tiers, then share what
exists in proportion, so no tier starves another by array order.

**Two severities.** Basic unmet → colonists leave relatively fast
(`declinePerMin` 6.0, scaled by shortfall). Luxury unmet → the tier is unhappy,
which blocks promotion *and* causes very subtle attrition
(`unhappyAttritionPerMin` 0.5, scaled by discontent).

**Happiness** is 0–1, the **mean** across luxury needs (comfort is cumulative
rather than gated by the worst item), pinned at 1.0 for tiers with no luxuries —
so Survivors can never be unhappy and promote freely once fed.

**Basic satisfaction** takes the **tightest** need — survival *is* gated by the
worst item.

**Promotion** requires basic needs met, happiness 1.0, and free capacity above.
Evaluated highest-rung-first so nobody promotes twice per tick.

**Tuning:** `growthPerMin` 3.0, `promotionPerMin` 2.0.

**Visibility (progressive reveal):** active tiers render normally, the single next
rung renders dimmed, everything beyond is hidden.

**The workforce squeeze — Anno's contribution, and central.** When colonists
advance a tier they *stop* providing the previous tier's workforce, so every tier
must be maintained. Promoting everyone upward starves lower-tier industry. Not
optional. §5 gives this its narrative form at the top of the ladder.

**People stay, goods move.** Colonists are not transportable between colonies;
their needs are. Taken from OGame (`OGAME_COMPARISON.md` §3.9) — it forces each
colony to grow its own society, gives trade its purpose, and protects the
workforce squeeze from being trivially solved by relocation.

## 11. Fleet

| Type | Role |
|---|---|
| `Ship` | Transit data in **fields**: `locationID`, `destinationID`, `remainingMinutes`. |
| `ShipStatus` | Plain enum `{ idle, docked, inTransit }`, no associated values. |
| `ShipRole` | `freighter, scout, escort, explorer` + stats + build cost/time. |
| `ShipBuildOrder` | An entry in `Colony.shipyardQueue`. |
| `BuildCost` | `{ credits, materials: [MaterialRequirement] }` |
| `Destination` | Static world registry. Slug ids + `GalaxyCoordinate`. |

- Travel time = `destination.travelTimeMinutes / role.speedMultiplier`
- Re-routing an in-transit ship is allowed
- Arrival flips the ship to `.idle`, restoring the amber "wasted capacity" warning
- `.docked` is **fully dormant** — unreachable in code. Reserved for "at a stop on
  an assigned trade route"; resolve its fate when the trade fork is decided (§20)
- Construction: real queue, real build time. Costs **deducted in full upfront** at
  queue time — credits from the empire, materials from the building colony's stock

**Ship costs:**

| Role | Refined Alloy | Alloy Tools | Power Cells | Credits | Build min | Speed |
|---|---|---|---|---|---|---|
| Scout | 25 | — | 20 | 500 | 5 | ×2.0 |
| Freighter | 40 | 10 | 25 | 800 | 8 | ×1.0 |
| Escort | 60 | 25 | 40 | 1,200 | 12 | ×1.2 |
| Explorer | 50 | 20 | 50 | 1,500 | 15 | ×1.5 |

**Planned (Phase 3):** cargo as a real integer; **loading is a withdrawal**,
arrival is a deposit; fuel that occupies cargo space; a speed slider trading fuel
for time; a fleet moves at the speed of its slowest ship.

**Standing rule:** everything the ship UI displays must be implemented for real at
some point. `cargoCapacity`, `shields`, `weapons` are currently invented
placeholders. A commitment, not decoration. Cargo lands in Phase 2, combat stats
in Phase 7.

## 12. Research

`ResearchProject` with `{ locked, available, inProgress, completed }`, filtered by
`ResearchCategory` chips (Production / Fleet / Defense / Habitat). Empire-scoped;
the global/local split is a Phase 5 decision.

Points are generated by **Ascendants** (not "Scholars" — Anno's term). Unlocking
is gated on Standing (§4.6). Population thresholds gate availability (Phase 5),
taken from OGame's lifeform-slot model — workforce is the *cost* of population,
gating is the *reward*.

**Currently inert.** See §18 S10.

## 13. Planned systems

Not built. Recorded here so the shape is settled before they land.

**Buildings and levels (Phase 4).** Levels go on a new **`Building`** concept, not
on chains directly — Helios's chains *already are* buildings ("Ice Harvester" is a
building running a chain), so `Building` spans production plus the Habitat /
Storage / Defense categories the chips already name. Unifies the taxonomy and
finally gives the category chips a job.

**Level exponents:** ~`1.1` output / `1.5` cost. **Cost's base must stay above
output's** or later levels get cheaper in real terms and pacing inverts. The
derived payback curve `(3/(4L))·(15/11)^L` gives a balance check you can compute
rather than playtest. If Helios's pacing needs it gentler, `1.08`/`1.4` — but keep
the ordering.

**Plot cap.** Yes. It is what makes world types and multi-colony mean anything,
and it must land *together* with levels — levels without a cap is "build
everything, slightly better"; a cap without levels is pure restriction. In fiction
the cap is Writs (§4.5).

**World-type production modifiers.** Ice / Arid / Oceanic / Volcanic / Gas Giant
become mechanical, not cosmetic. Plot count *and* per-resource multipliers are the
two knobs; neither works alone.

| World | Plausible modifier shape |
|---|---|
| Ice | Ice Harvester ×2, Hydroponics penalised |
| Volcanic | Ore and energy bonus, life-support penalty |
| Oceanic | Water and food bonus, ore scarce |
| Arid | Solar/energy bonus, water heavily penalised |
| Gas Giant | Fuel/gas extraction only, no surface plots |

**Storage as a levelled building.** `Resource.capacity` stops being static.
Storage becomes protective as well as productive, and it is what makes offline
absence meaningful rather than free.

**Loss / hazards (Phase 7).** Bounded: hazards take only stock *above* storage
capacity — never population, never buildings. Raid-type hazards steal *and*
destroy more; environmental events are milder.

**Combat resolver (Phase 7).** OGame's algorithm taken near-verbatim (~60 lines):
≤6 rounds, simultaneous, random targeting, shield→hull, per-hit explosion roll
below 70% hull, rapidfire re-roll, shields regenerating between rounds. The
per-hit explosion roll is what makes swarms beat few — the most important balance
property. Full spec in `OGAME_COMPARISON.md` §3.8.

**Colony score (Phase 5).** **Standing is the score** (§4.1), with reliability as
its input, sub-scored economy / research / military / defence. Must be designed
knowing it will eventually be public.

---
---

# Part III — The build as it is

*Verified against commit `e5ae9ca`, 28 Aug 2026.*

## 14. Architecture

### Scope split

Following Anno's precedent — gold global, goods and population per-island, ships
global:

| Empire — `GameState` (`@Observable` class) | `Colony` (struct) |
|---|---|
| `colonies: [Colony]`, `activeColonyID` | `id` (== `Destination.ID`) |
| `credits` | `stock: ColonyStock` |
| `ships` | `population: Population` |
| `researchProjects`, `researchPoints`, `researchRatePerMin` | `productionChains: [ChainDetail]` |
| `lastTickAt` | `shipyardQueue: [ShipBuildOrder]` |
| | `gridSupply`, `gridDemand` |

`Colony.ID == Destination.ID` — one colony per destination, so there's no separate
identifier to keep in sync. `Colony` resolves `name` and `worldType` from the
destination registry.

`Colony` is a **struct**: no Observation, no SwiftUI, so the simulation stays
portable. Views read through a non-optional `game.activeColony` computed property
— deliberately *not* proxy accessors on `GameState`, which would be a facade
hiding the structure.

`Colony.applyTick` **returns** completed `ShipBuildOrder`s for the empire to turn
into ships, because ships are empire-scoped and a colony can't create them.

**Constraint:** mutate array elements by index (`colonies[i].stock`,
`chains[i].status`), never wholesale-replace an element — replacement breaks the
stable identity navigation depends on.

### State

`@Observable` `GameState`, injected with `.environment(gameState)` at the app
root, read via `@Environment(GameState.self)`. `GameState.seeded()` is the seed
factory.

**Convention:** `GameState` holds game data; transient *view* state (filter chips,
sheet flags) stays local `@State`.

**Footgun:** any view reading the environment needs `.environment(GameState.seeded())`
in its `#Preview`, or it crashes.

### Navigation

Persistent tab bar: `RootView` owns `selectedTab` and hosts one `NavigationStack`
per tab, with a single `GlassTabBar` floating above so it survives pushes.

- Tab roots (Colony, Production, Fleet, Research) have **no** back chevron
- Detail screens hide the native back button and use a glass `CircleGlassButton`
  wired to `@Environment(\.dismiss)`
- Payloads are `Hashable`: `ChainDetail.ID`, `ShipRouteTarget`, `ProductionListNav`

### Game loop

`RootView` drives it with `Timer.publish` at `GameState.tickInterval` (needs
`import Combine`; `GameState` needs `import Foundation` for `TimeInterval`).

Two pacing levers, split so they never have to be untangled:

- `economyRate` — production, population, research
- `fleetRate` — ship travel **and** shipyard build time

Both currently `1.0` (**accelerated**: one tick applies a full per-minute rate, so
one tick = one game-minute). Phase 3 dials `economyRate` to 1/60.

`tick()` is a **pure step that reads no clock**, so Phase 3 can replay it in a
loop. `advanceOneTick(now:)` wraps it and stamps `lastTickAt` — that's what the
timer calls. Order within a colony: **population eats first**, then production
chains, then the shipyard; ships advance at empire level afterwards.

### Portability — the multiplayer constraint

Asynchronous multiplayer in a shared persistent galaxy, **server-authoritative**,
is planned after Phase 7. This constrains code written now.

OGame can project resources client-side because its production is **linear**.
Helios cannot: the sim is **path-dependent** (chains stall and throttle,
population promotes and declines, energy and workforce scale everything). There is
no closed form to interpolate. So the client will eventually run the same
simulation locally as a prediction and reconcile against server snapshots —
requiring the sim to be deterministic and identical on both sides. Beware
floating-point divergence if the server isn't Swift.

**Hedges adopted**, all good hygiene regardless:

- `applyTick` logic lives in pure value types — no SwiftUI, no Observation. This
  is why colour mappings were moved out of the models into `ModelStyles`.
- `lastTickAt` stored rather than assuming continuous ticking
- No randomness inside `tick()` — **currently violated**, see §18 S5
- `Destination` carries a `GalaxyCoordinate` (discrete `galaxy:system:position`,
  OGame-shaped) with a `distance(to:)` formula. **Not yet wired** — travel time is
  still authored per destination

### Prior art

An earlier headless, **JSON-driven** `SimulationCore` Swift Package
(`ProductionEngine`, `TierEvaluator`, `SimulationClock`, 16 passing tests) exists
as reference, not active code. The JSON-driven data shape is worth remembering —
authored data loaded rather than compiled in is what a server-side sim would want
too. Its logic plugs in at the `ProductionAllocator` seam — and the
multiplayer plan makes reviving that separation genuinely necessary rather than
merely tidy.

## 15. Project structure

One struct per file; filename matches the type name.

```
App/            HeliosApp, ContentView, RootView
DesignSystem/   DesignSystem, ModelStyles
Shared/         VoidBackground, CircleGlassButton, GlassTabBar, Format
Backgrounds/    PlanetBackdrop
Persistence/    SaveStore
Models/         see §17
Components/     see §17
Screens/        MainColonyView, ProductionListView, ProductionDetailView,
                FleetView, ResearchView, RouteSelectView, BuildShipSheet
```

> **Correction to the old design doc:** it listed `PlanetBackdrop` under
> `Shared/`. It is in `Backgrounds/`.

**Sample data convention.** Static properties **on the model**, never the view:
`sample` (single), `samples` (collection), `sample<Variant>` (suffix, so
autocomplete groups them). These became `GameState`'s seed values rather than
being deleted.

## 16. Visual language

- Glassmorphism over a deep navy/void space background
- `VoidBackground` = gradient + nebula glows + starfield
- Cyan accent, ~RGB `0.30 / 0.85 / 0.95`
- Amber (`GameTheme.warn`) reserved **strictly** for alerts and blocked states
- Dark mode only (`.preferredColorScheme(.dark)`)

**Provenance.** The panel style, floating capsule buttons and glass tab bar were
informed by glassmorphism app screenshots — a food app and a plant-shop app —
used as reference material during the original visual pass.

**Design system** — `DesignSystem.swift`, nested-enum tokens for scalability. The
nesting was chosen anticipating categories that don't exist yet (`Motion`,
per-world palettes), so autocomplete stays organised rather than becoming one long
flat list:

| Namespace | Members |
|---|---|
| `GameTheme` (colors) | `voidTop, voidBottom, accent, accentDim, warn, textPrimary, textSecondary` |
| `GameTheme.Spacing` | `xs 6, sm 10, md 14, lg 18, xl 20, xxl 24` |
| `GameTheme.Radius` | `chip 16, pill 14, row 18, panel 24, hero 26, tabBar 28, circleButton 20, iconBadge 14` |
| `GameTheme.Size` | `iconBadge 46` |
| `GameTheme.GlassStroke` | `subtle .14, standard .18, prominent .20` |
| `GameTheme.Font` | `label, caption, body, chipLabel, rowTitle, sectionTitle, heroValue, heroTitle, tabLabel` |

**Rule: reference tokens, never raw literals.** `.glass()` (backed by `GlassPanel`)
is the shared panel style. If you reach for a fourth stroke value, reconsider the
hierarchy instead of adding one.

`DesignSystem/ModelStyles.swift` holds every model→colour mapping as a view-layer
extension: `ChainStatus.tint/indicator`, `ShipStatus.tint`, `DangerLevel.tint`,
`WorldType.baseColor/bandColor`. **These deliberately do not live on the models.**

`Shared/Format.swift` is the single source for display formatting: `Format.decimal`
(one decimal), `Format.integer` (locale-grouped), `Format.duration(minutes:)`
(`"3h:20:00"` / `"20:00"`).

## 17. Verified inventory

**44 Swift files**, as of commit `e5ae9ca`. ⚠️ **The table below is a Phase 0–1a
snapshot and has not been re-counted since.** Phases 1.5 and 2 added
`SaveStore`, `GameSave`, `ChainID`, `ResearchID`, `ShipID`, `ShipNameGenerator`,
`SeededGenerator`, `CapacityProbe`, `Quota`, `QuotaGenerator`, `QuotaLedger`,
`QuotaSettlement`, `QuotaDetailNav`, `Standing`, `Commission`,
`CommissionGenerator`, `QuotaPanel`, `QuotaLineRow`, `CommissionCard` and
`QuotaDetailView`, and removed `DebugSink`. Tests are no longer boilerplate:
six suites across five files. Re-count when §17 next matters.

| Group | Files |
|---|---|
| **App** (3) | `HeliosApp`, `ContentView`, `RootView` |
| **Models** (22) | `Resource`, `ChainDetail`, `ChainFlow`, `ChainStatus`, `LimitReason`, `ProductionAllocator`, `ProductionListNav`, `BuildCost`, `Colony`, `ColonyStock`, `ColonistTier`, `Population`, `TierPopulation`, `PopulationNeed`, `Ship`, `ShipBuildOrder`, `ShipNameGenerator`, `ShipRouteTarget`, `Destination`, `GalaxyCoordinate`, `GameState`, `ResearchProject` |
| **Screens** (7) | `MainColonyView`, `ProductionListView`, `ProductionDetailView`, `FleetView`, `BuildShipSheet`, `RouteSelectView`, `ResearchView` |
| **Components** (16) | `TierRow`, `PopulationPanel`, `WorkforceSection`, `ProductionChainRow`, `ChainFlowDiagram`, `FlowResourceCard`, `ResourcePill`, `ShipRow`, `FleetSummaryStrip`, `BuildOrderRow`, `DestinationCard`, `ResearchProjectRow`, `ResearchSummaryStrip`, `CategoryChip`, `BlockedBanner`, `RoleStatRow` |
| **Design system** (2) | `DesignSystem`, `ModelStyles` |
| **Shared / backgrounds** (5) | `GlassTabBar`, `CircleGlassButton`, `VoidBackground`, `Format`, `PlanetBackdrop` |

**Player-facing actions that exist today:** queue a ship; dispatch a ship. That
is the complete list — see §18 S2.

**Registries:** 9 resources, 5 destinations, 10 chains, 4 ship roles, 5 research
projects, 5 colonist tiers (2 with defined needs).

---
---

# Part IV — Known issues

## 18. Ranked, with status

Full evidence and reproduction in `AUDIT-2026-08-28.md` (Claude project). Findings
verified by a line-for-line Python port of `ProductionAllocator` + `Population` run
for 1,200 ticks against `GameState.seeded()`.

| # | Issue | Severity | Answered by |
|---|---|---|---|
| **S1** | **Resolved, Phase 2 (4–13 Oct 2026).** Quota delivery is the sink. Measured over 5,000 ticks with no player action: no chain reports `.stalled`, every chain but the two structural Refined Alloy consumers runs at exactly the rate it was asked for, mean store fill is 0.40 and population holds at 450. The sink is *permanent* because settlement starts a new cycle — a completed manifest has no collectable allowance left, and an early version of this phase shipped without that and saturated by ~tick 300, which is S1 arriving through its own fix. One store is deliberately not low: oxygen holds a full tank, a one-off ~200-unit surplus the seed colony's population ramp deposits and which nothing at load 1.0 removes. It is a survival buffer, not saturation — the Recycler runs at 100% and the output-% lever still moves it — and it is pinned by a test. | — | Done |
| **S2** | **No player agency over the economy.** Two actions exist in the whole app. Output %, workforce, building, starting research: none. | Critical | Output % (Phase 1a) |
| **S3** | **Resolved, Phase 2 (4–13 Oct 2026).** A stipend is paid on settlement, scaled by fill and by the Standing band: 300 credits for a met quota at Indifferent, which puts a Freighter within 2.67 cycles. Receivership pays nothing and the goods still leave. Twenty settled cycles from the seed state earn enough for two Freighters several times over, which is the regression test. Note the opposite problem is now visible and deferred: credits outrun their sink until Writs land in Phase 5, and materials — Refined Alloy above all — remain the real constraint. | — | Done |
| **S4** | **Resolved, Phase 1.5 (2–4 Sep 2026).** Every model that isn't authored data round-trips through `Codable`; `GameSave` (versioned) is written atomically to Application Support on `scenePhase` → background/inactive and loaded at launch, falling back to a fresh game on a missing, corrupt, or unsupported-version file (quarantined as `save.corrupt.json` rather than destroyed). | — | Done |
| **S5** | **Resolved, Phase 1.5 (2 Sep 2026).** `ShipID` replaces `Ship.id = UUID()`; a monotonic `GameState.nextShipSerial`, itself part of saved state, mints ids deterministically. `tickIsDeterministic` pins two identically-seeded runs to identical stock, throughput and ship ids over 200 ticks. | — | Done |
| **S6** | **Resolved, Phase 1a (28 Aug 2026).** Grid demand used `energyRequired × outputCap` computed *before* input allocation, so an input-starved chain still booked full power draw. Fixed: demand now scales by `outputPercent` too, reflecting what each chain will actually draw. | — | Done |
| **S7** | **Resolved, Phase 1a (28 Aug 2026).** `Colony.gridFactor` was a separately computed re-derivation of `ProductionAllocator`'s internal `energyFactor` — the UI rendered one, the sim obeyed the other. Fixed: `ProductionAllocator.run` now returns the factor it used, and `Colony.gridFactor` stores it verbatim. | — | Done |
| **S8** | **Resolved, Phase 1.5 (2 Sep 2026).** Twelve tests over `ProductionAllocator` and `Population`, every expected value measured against the real allocator (Appendix C) — including S1's saturation scenario, pinned as a permanent regression test. Four more tests cover the Step 5 persistence round trip. | — | Done |
| **S9** | `Models/ResearchProject.swift` **imports SwiftUI** (`ResearchCategory.icon`). One crack in the constraint the multiplayer plan rests on. | Low | Move to `ModelStyles` |
| **S10** | **Research entirely inert**, and the UI doesn't say so — "+12/min from Ascendants" with zero Ascendants and a number that never moves. `status` is a `let`. | Medium | Archive (§4.6), Phase 5 |
| **S11** | **Unenforced fields:** `requiredTier` (never checked), `workforceAssigned/Required` (display only; Tool Fab seeded 5/6), `providesWorkforce` (unused), `LimitReason.workforce` (never produced but styled and captioned), `GalaxyCoordinate.distance` (unwired). **`ChainStatus.paused` is now produced** (Phase 1a, 28 Aug 2026) — `outputPercent == 0` reports it; the rest of this row is still open. | Medium | Phase 1 (workforce), §5 |
| **S12** | **Resolved, Phase 1a + Phase 1.5 (28 Aug – 2 Sep 2026).** Phase 1a's `@State` fix stopped the per-tick re-roll but not a per-tab-switch one: `RootView` selects tabs with a `switch`, so each tab is a distinct view identity, and switching tabs tore `VoidBackground`'s `@State` down and regenerated it. Phase 1.5 Step 1 made the starfield a `private static let`, generated once per launch and shared by every instance — it does not want per-view identity at all. `PlanetBackdrop` now takes a `seed: Int` (new `SeededGenerator`, SplitMix64) so a given world looks identical every time it's opened, while different worlds still differ. See §23. | — | Done |
| **S13** | **Doc drift** — resolved by this document. Recorded in §21 for the record. | — | Done |
| **S14** | **Resolved, Phase 1.5 (2 Sep 2026).** The two items that actually mattered for persistence: `ChainDetail`/`ResearchProject` now use slug ids (`ChainID`/`ResearchID`), consistent with the rest of authored data — a regenerated `UUID()` would have orphaned every save's chain/project references on next launch. Duplicate `.navigationDestination(for: ChainDetail.ID.self)` registration removed; registered once per stack, in `RootView`. **Still open, low priority, not worth their own row:** `ContentView` is a pure passthrough; the ticker is attached to `GlassTabBar` (hide the bar and time stops); `kepler-7` has `travelTimeMinutes: 0`. | — | Done |
| **S15** | **Resolved, Phase 1a (28 Aug 2026).** `resolveStatus` compared achieved throughput to `1.0` with a `0.001` tolerance, so chains at 99.5% throughput reported "Limited" in amber — measured at 8 of 10 chains, 100% of ticks, once a sink existed. Fixed: status is now measured against `outputPercent` (`attainment = achieved ÷ outputPercent`), tolerance widened to `0.02`. Verified: with the debug sink on and all chains at 100%, exactly two — Alloy Tool Fab and Cell Factory — read amber, both "Limited by Refined Alloy", the real structural bottleneck. | — | Done |

### What's working, and worth protecting

- **The colony-wide pool over declared chain links.** Emergent interlinking with
  no dependency graph is why the allocator stays ~140 lines.
- **The two-phase allocator.** Exempting energy producers from their own grid
  factor is a subtle failure mode correctly anticipated and correctly solved.
- **Model/view purity.** One violation (S9) in 44 files.
- **`tick()` reads no clock.** Decided before it was needed.
- **The decision log.** Rejected alternatives recorded alongside choices.
- **The design system.** Token discipline near-total.

---
---

# Part V — The plan

## 19. Phases

Revised from the original roadmap in light of §18 and Part I. Changes from the
original ordering are marked **▲**.

### Phase 0 — Structure ✅ complete
Split `rateMultiplier` into `economyRate`/`fleetRate`; Empire/Colony split;
restore `PlanetBackdrop`; wire material costs into `BuildCost`; multiplayer hedges.

### Phase 1 — Unified throughput *(Output % complete; workforce still pending)*

| Item | Status |
|---|---|
| `throughput: Double` alongside `ChainStatus` | ✅ |
| Universal proportional allocation | ✅ |
| Energy as a live per-colony balance | ✅ |
| One combination rule | ✅ **multiply** — settled in code, recorded here for the first time |
| **Player-set output % per chain** | ✅ **Phase 1a, 28 Aug 2026** |
| Workforce as a factor | ❌ scaffold only |
| UI: Grid readout, per-chain throughput | ◐ partial |

**Phase 1a is complete** (28 Aug 2026, six commits — `briefs/phase-1a-output-percent.md`).
Shipped output %, and in the same lines of code, fixed S6 (grid demand), S7 (two
grid factors), S12 (backgrounds), and S15 (status tolerance). See §18 for each.

**▲ Output % moved to the front of Phase 1** — but it did **not** close S1, and
an earlier version of this document (and the audit) claimed it would. Corrected by
simulation, 28 Aug: in a saturated economy, throttling a chain changes only which
store is full. Refined Alloy sits at 149/150 whether the Tool Fab runs at 100% or
0%. Output % closes **S2** — it is the first real decision the player gets — but
the lever moves nothing until something is pulling goods out of the colony.

Consequence: Phase 1a shipped a **temporary debug sink** (`Models/DebugSink.swift`)
so the feature is testable and feelable at all. **It is scaffolding, flagged as
such in its own doc comment, and must be deleted when Quota lands in Phase 2.**

Workforce follows — the more interesting mechanic, the less urgent one.

**Note:** energy producers are themselves chains. The exemption is already
implemented; don't undo it.

### Phase 1.5 — Persistence and determinism ▲ ✅ complete *(2–4 Sep 2026, seven commits — `briefs/phase-1-5-tests-and-persistence.md`)*

- Stable starfield (per-launch, not per-view) and seeded-per-world planets (S12)
- Test target over `ProductionAllocator` and `Population` (S8) — twelve tests,
  including S1's saturation scenario as a permanent regression test
- Slug ids for `ChainDetail`/`ResearchProject` (S14); fixed the duplicate
  `.navigationDestination` registration along the way
- Fixed `UUID()` inside `tick()` (S5): `ShipID` + monotonic `nextShipSerial`
- Made the value types `Codable` on the **blueprint-overlay** principle — a save
  stores ids and mutable fields only, authored data is rehydrated from the
  registry (S4 in part); `GameSave` versioned from day one. Four more tests
  cover the round trip and the unknown-id-drop behaviour
- `SaveStore`: atomic JSON to Application Support, saved on `scenePhase`
  background/inactive, loaded at launch with fallback to `.seeded()` and a
  `save.corrupt.json` quarantine for anything unreadable (closes S4)

**Not done here, despite the original plan below claiming it would be:**
moving `ResearchCategory.icon` out of `Models/ResearchProject.swift` (S9) —
the brief that actually shipped this phase scoped it out. S9 stays open.

**Why here:** real-time quota cadence (§4.8) makes persistence a hard
prerequisite, not a convenience. It is also a day's work now and grows with every
new model.

### Phase 2 — The Empire ▲ ✅ complete *(4–13 Oct 2026, nine commits — `briefs/phase-2-the-empire.md`)*

The narrative layer, and the fix for S1/S3.

| Item | Status |
|---|---|
| `CapacityProbe` — installed export capacity, measured rather than derived | ✅ |
| Quota: manifest generation, ledger delivery, settlement, shortfall | ✅ |
| `GameState.tickCount` — the persisted integer clock the Empire runs on | ✅ |
| Standing: reliability EMA, bands, hysteresis, cadence | ✅ |
| Stipend on settlement | ✅ |
| Commissions (optional contracts) | ✅ |
| UI: quota panel, detail screen, next cycle, commission card | ✅ |

**Why before cargo:** quota is what makes hauling matter. Building the fleet↔economy
loop first means building it without a reason for anything to move.

**What it closed:** S1 and S3, both by measurement rather than by argument — see
§18 and Appendix C.

**What it left open, and this is the important part:** at load 1.0 the quota is
meetable with no effort, so Standing reaches Patron in two settlements and
commissions are almost never worth accepting. Both mechanisms are correct and
both are inert. The cause is that the colony has no spare capacity, and there is
no load that gives both drained stores *and* spare capacity — by construction,
since spare capacity **is** stores filling up. The missing piece is a second
sink, which is Phase 5's `Building` work. Quota is pressure; building is agency.

### Phase 3 — Fleet ↔ economy loop *(was Phase 2)*

- Cargo as a real integer quantity
- **Loading is a withdrawal**, arrival is a deposit
- Fuel and the speed slider ride along or defer
- Quota shipments become real fleet operations

Discharges part of the standing rule on display-only ship stats.

### Phase 4 — Honest pacing + offline *(was Phase 3)*

- Dial `economyRate` to 1/60
- Tick-replay catch-up on resume, with a cap (~7 days), honest about it in the UI
- Quotas auto-settle from stores on hand while away (§4.8)

Replay, not closed form: the sim is path-dependent. Later is better — the more
that exists, the more replay covers for free.

### Phase 5 — The vertical axis *(was Phase 4; likely splits 5a/5b)*

- A `Building` concept spanning production, Habitat, Storage, Defense
- Levels with `1.1`/`1.5` exponents
- Plot cap per colony, expressed as Writs
- World-type production modifiers
- `Resource.capacity` becomes a levelled storage building
- Favour and Dispensations

These must arrive together. Also consider per-resource vs per-chain halting
granularity here.

### Phase 6 — Legibility

- Standing as the score, with sub-scores
- Population thresholds gating `ResearchProject` availability
- Research global vs local split (settle before multi-colony)
- **`MainColonyView` redesign** — by now it must absorb a Grid readout, standing,
  quota status, and throughput badges

### Phase 7 — Multi-colony

- World-switcher UI
- Discrete missions proper
- Colony claims as the most expensive Writ

### Phase 8 — Risk & combat

- Hazard types with differing severities, bounded loss
- Combat resolver (`OGAME_COMPARISON.md` §3.8)
- Discharges the standing rule on `shields`/`weapons`

### Phase 9 — Asynchronous multiplayer

Server work. The Empire keeps the ledger. See §14 portability.

## 20. Open questions

Consolidated from all four superseded documents plus this session. Nothing
dropped.

### Fiction and the Empire
1. **Can you deliberately refuse a mandatory quota?** Trading Standing for
   materials you need now is a good decision to offer. Risk: players discover
   Receivership is survivable and opt out of the system entirely. Possible
   answer — refusal allowed, but dock collection makes it strictly worse than
   paying, so it's a *delay* tactic, never an *exit*. **Biggest open risk.**
2. **What sets quota composition?** Assessed capacity plus Empire demand
   elsewhere. Must be legible enough to anticipate.
3. **How many Dispensations, and are they exclusive?** A short list you can only
   partly hold beats a long list you eventually own outright.
4. **Does Standing gate colonisation itself?**
5. **How much predecessor story to tell?** (§1)
6. **Are other administrators the multiplayer opponents?** Likely yes — raids
   become "unreported losses in transit."
7. **Names** — §7.

### Systems
8. **Per-resource vs per-chain halting granularity.** OGame halts per resource;
   Helios per chain. Finer is probably wanted eventually. Phase 5.
9. **Research global vs local**, or split by `ResearchCategory`. Phase 6.
10. **Tier 3–5 needs** — shape given in §5, numbers undesigned.
11. **Trade routes vs discrete missions**, and therefore does `.docked` live or
    die? Settled direction: discrete missions first, standing routes unlocked
    *very late* as a reward. Confirm and resolve `.docked`.
12. **Hazards: purely environmental pre-multiplayer, or PvE raiders?**
13. **Ellipsis menu contents per screen** (colony: rename, abandon).
14. **Compact number notation** (`1.2M`) — when numbers actually grow, not
    speculatively.
15. **Category chips** on `MainColonyView` — currently cosmetic; Phase 5 gives
    them a job via `Building`.

---
---

# Part VI — Decision log

## 21. Decisions, with rationale and rejected alternatives

*Append-only. Newest first within each group.*

### Narrative (28 Aug 2026)

**The Empire's posture is dynamic, driven by reliability.** Rejected: static
benevolent (toothless), static extractive (pushes to a rebellion plot), pure
indifference (no feedback). The band system gives the score a job and makes the
long arc a slope rather than an event.

**Failure shortens the interval, never raises the rate.** Rejected: harsher quotas
on failure — self-reinforcing, structurally identical to the brownout trap.

**Standing measures reliability (ratio), not size.** Prevents the OGame
points-distortion where staying small is strictly optimal.

**Quota names specific goods.** Rejected: bulk tonnage — it wouldn't force
retasking, and retasking is the entire "presence decides" payoff. Named goods also
make colonisation a need rather than an option.

**Three currencies, cleanly separated** (Credits / Favour / Research Points). No
source feeds two, no currency has two sinks.

**Ascendants are citizens of the core.** They pay in Favour and Research and
provide no workforce. Gives `providesWorkforce` its reason and turns the tier
ladder from a track into a curve. The control lever is habitat capacity, which
already gates promotion — no new mechanic.

**Dispensations change how you play, not how much.** Anything expressible as
"+10% X" belongs in research.

**A quota is a ledger, not a snapshot** *(simulated, Appendix C)*. Deliveries
accumulate across the interval. **Rejected:** settling from stores on hand at the
deadline — it silently caps quota size at storage capacity rather than production,
making long intervals unmeetable (19× storage at 960 minutes) and turning good
standing into a punishment. Ledger delivery makes interval length economically
neutral, which is what the cadence bands require.

**Quota is sized per good from measured export capacity × interval × load, at
load ≈ 1.0** *(simulated)*. Below 0.75 it isn't a sink; above 1.2 it kills the
colony. The usable band is narrow and must be re-measured whenever the chain
network changes.

**Basic-need goods have a reserve floor the quota cannot cross** *(simulated)*.
Without it, load 4.0 empties the colony to zero population. Luxuries stay
contested deliberately — that contest is the squeeze.

### Architecture

**Design tokens: nested enums over flat statics.** Nested namespacing keeps
autocomplete organised as categories grow.

**Sample data on the model, not the view.** A view shouldn't need to know what
example data looks like. Surfaced when `ChainDetail.sample` and
`ProductionDetailView.sample` diverged.

**Unify parallel models early.** `ProductionChain` and `ChainDetail` were linked by
`matching(name:)` — a string lookup with nothing enforcing consistency. Unified at
three chains, when it was cheap. **Rejected:** link-by-ID (still two objects to
sync), defer (bakes the fragility deeper).

**Enum over nullable string for state.** `ChainStatus` replaced
`missingInputName: String?`; `ShipStatus` dropped associated values in favour of
fields. A thing is in exactly one state. Applied twice.

**Slug ids for authored data.** `Destination.ID`, `Resource.ID`,
`MaterialRequirement.resourceID` are hand-written strings, not UUIDs. Seed data can
reference them, they're debuggable, and they survive save/load. Killed a
casing-mismatch bug. **Note:** `ChainDetail` and `ResearchProject` still use
`UUID()` — inconsistent with this decision (§18 S14).

**Colony pool over chain-to-chain links.** Interlinking is emergent. Also killed
the struct-vs-class question for `ChainDetail`: with a pool there are no shared
mutable resource objects.

**Components stay pure functions of their inputs.** `FleetView` resolves
destination names and passes them into `ShipRow`. This is why `FleetSummaryStrip`
needed zero changes across three migrations.

**Population eats before industry.** Colonists win contested resources, so
shortages surface as *blocked production* — diagnosable — rather than silent
population decline. Revisitable.

**Shipyard queue per colony, ships per empire.** A queue is a *shipyard* — a
building at a place. Ships move between colonies once built. Also answers "which
colony's materials pay for this?"

**`tick()` reads no clock.** Timestamping lives in `advanceOneTick(now:)`. Keeping
the step pure is what makes replay-based offline catch-up possible.

### Simulation

**Universal proportional allocation** over energy-only throttling or a hybrid
divisible/discrete split. Kills array-order dependence everywhere; shortages become
graceful degradation. Cost: `ChainStatus` gained a companion `throughput: Double`
rather than staying a clean three-case enum. `OGAME_COMPARISON.md` §3.1 option B.

**Combination rule: multiply, not minimum.** Harsher and more legible. *Settled in
code during Phase 1 and recorded here for the first time — the old roadmap still
listed it as open.*

**Energy producers are exempt from the grid factor** (resolved in Phase A). Without
it a brownout is self-reinforcing. Producers therefore also get first call on
shared inputs — deliberate.

**Happiness is the mean across luxuries; basic satisfaction is the tightest need.**
Comfort is cumulative; survival is gated by the worst item.

**Levels on `Building`, not on chains.** Helios's chains already *are* buildings, so
`Building` spans production plus Habitat/Storage/Defense and unifies the taxonomy.

**Plot cap: yes, and it must land with levels.** Levels without a cap is "build
everything, slightly better"; a cap without levels is pure restriction.

**Shipping colonists: no.** Protects the workforce squeeze. Ship the needs, not the
needers.

**Loss: yes, bounded.** Hazards take only stock above storage capacity — never
population, never buildings.

**Colony scope per-colony from Phase 0.** Restructuring before buildings and plots
land is far cheaper than after.

**Offline: replay, not closed form.** The sim is path-dependent; there is nothing to
interpolate.

**Two pacing multipliers, not one.** Economy and fleet, split before dialling
either.

### Implementation — Phase 1a (28 Aug 2026)

**Status compares achieved throughput to what was requested, not to 1.0.**
`resolveStatus` computes `attainment = achieved ÷ outputPercent` and checks that
against a widened tolerance (`0.02`, up from `0.001`). **Rejected:** leaving the
comparison against `1.0` — a throttled chain running exactly at its requested
rate would always report `Limited`, which is backwards. S15.

**Output % is five discrete stops (0/25/50/75/100%), not a continuous slider.**
This is a phone; coarse touch targets beat precision here.

**Grid demand scales by `outputPercent`, not just `outputCap`.** Otherwise
throttling a chain never freed power for the rest of the colony — the whole
point of S6. The desired-rate calculation in `ProductionAllocator.allocate` and
the grid-demand sum in `run` share the same `outputPercent` multiplier, which is
also what makes it apply to energy producers automatically — they go through
the same `allocate`, no special-casing needed.

**`ProductionAllocator.run` returns the grid factor it used; `Colony.gridFactor`
stores it rather than recomputing it.** Closes S7. The two numbers were always
mathematically identical (same formula, same inputs) — the fix removes the
duplicate computation path before it has a chance to drift, not a live bug.

**Fixing S12 needed `@State`, not just moving `.random` out of `body`.** First
attempt hoisted the random generation into a plain `let` computed in a custom
`init` — looked right in a static preview, but SwiftUI reconstructs a view
struct (re-running `init`) every time its parent's body re-evaluates, which is
every tick here. A plain `let` has no memory across that reconstruction; only
`@State`'s persistent, identity-keyed storage survives it. Caught by testing on
device, not by review — see §23.

**The output-% caption is always visible, not just when throughput and request
diverge.** Rejected: conditional display — it flickered in and out within a tick
or two of tapping a stop (throughput catches up almost immediately), which read
as broken rather than confirming what was just set.

### Implementation — Phase 1.5 (2–4 Sep 2026)

**A save file stores mutable state only; authored data is rehydrated from the
registry on load.** A chain saves `id`, `outputPercent`, `throughput` and
`status` — never name, icon, rates, energy figures or required tier; those come
from `ChainDetail.blueprint(for:)`. Same shape for `ResearchProject` (`id` +
`status`). **Why this matters more than it looks:** serialising authored data
means a future rebalance never reaches anyone with an existing save, and
nothing in a bug report would tell you why — a standard, expensive idle-game
trap. The same principle already held for `Destination` and `Resource`, which
never carried mutable state to begin with.

**The blueprint-overlay `Codable` on `ChainDetail`/`ResearchProject` is an
interim measure.** It works today because "authored" and "runtime" are just
fields on the same struct, so overlaying means "decode a couple of fields,
copy the rest from a registry lookup." **Phase 5's `Building` concept should
split blueprint from runtime state as two actual types** — recorded now so
it isn't rediscovered as a surprise when `Building` design starts.

**An id absent from the registry is dropped, never resurrected as a husk.**
`ChainDetail`/`ResearchProject.init(from:)` throw on an unknown id;
`Colony`/`GameSave` catch that per-element via a `Slot` wrapper
(`try?` the element's own decode, `compactMap` away the failures) so one
retired chain or research project can't sink the whole array. **Rejected:**
relying on `UnkeyedDecodingContainer` to auto-advance its cursor past a
throwing element — that behaviour isn't documented as guaranteed, so a `Slot`
that owns its own sub-decoder is the safe version of the same idea.

**Custom `Codable` lives in an `extension`, never inside the struct's own
declaration.** A custom `init(from:)` written inside a struct's primary body
disables the compiler's synthesised memberwise initialiser; written in an
extension, it doesn't. Kept `ChainDetail.samples`, `ResearchProject.samples`
and `Colony.seeded` exactly as they were instead of hand-writing three
memberwise inits back by hand.

**`GameSave.version` decodes as required, not defaulted.** There is nothing
to default to yet — version 1 is the only format that has ever existed — and
treating a version mismatch as absent (same code path as a missing file)
keeps `SaveStore` from needing real migration logic before there's anything
to migrate from. `SaveStore.supportedVersion` is the single place that check
lives.

**Note for Phase 2 (raised by the brief, answered here):** Quota needs
`lastTickAt` saved — it now is — and a delivery ledger that survives a
relaunch. Nothing above makes that awkward: `GameSave` is a plain versioned
struct with explicit `CodingKeys`, so a ledger is an additive field, not a
redesign.

### Narrative and balance — Phase 2 (4–13 Oct 2026)

**Assessed capacity is *installed* capacity, not actual output** *(simulated)*.
Capacity is measured with every chain forced to `outputPercent = 1`. **Rejected:**
scaling quota with what the colony currently produces — turning a chain down
would lower next cycle's demand, and the optimal play would become running the
colony at minimum. That is the standing spiral arriving through a side door.
Throttling changes what you deliver this cycle, never what is asked of you next
cycle.

A measured consequence, recorded because it is not obvious: a **power-limited**
colony assesses *below* what a player who throttles can actually produce, since
the probe forces every chain to 100% — a state the grid cannot serve. With the
Power Plant at 90 MW instead of 240, measured capacity comes back at ~53% of
the healthy figures. Under-assessment errs toward the player, which is the safe
direction; the alternative — measuring the best output achievable under some
throttling strategy — would have the Empire optimise on the player's behalf and
the assessment *rise* the moment they played well. The cost is surplus with
nowhere to go, which is the second-sink gap again.

**Cadence is expressed in game-minutes until Phase 4.** §4.8 calls it
"real-time", and that remains the intent; a deadline is an absolute tick count
compared against a persisted `tickCount`. **Rejected:** comparing `Date()` inside
`tick()` — it breaks Phase 4's replay, Phase 9's reconciliation and the Phase 1.5
determinism test, all three.

**No new currency without a sink.** Commissions pay Standing and credits, not
Favour. Favour waits for Phase 5, where Dispensations give it somewhere to go.
Introducing a currency with a source and no sink is precisely how `credits`
became S3, and doing it a second time with the lesson in writing would be
careless.

**The load factor is left at 1.0, and it is the question Phase 2 hands forward.**
See §4.2. Measured: fill ≈ `min(1, 1/load)`, so reliability and tension are a
direct trade, and no load setting produces both empty stores and spare capacity.

### Implementation — Phase 2 (4–13 Oct 2026)

**Appendix C's published figures were wrong, and every one of them was wrong in
the same direction.** Each exceeded the arithmetic ceiling of the seed network at
full population — Ration Bars 0.23 against a hard ceiling of 0.15 (the Synth's
6.00/min minus 5.85/min eaten by 450 colonists), Water 0.56 against 0.50, and so
on down the table, by a near-constant +0.06/min. The cause was averaging across
the colony's population ramp (248 → 450 colonists), when fewer colonists were
eating. Noise on wide-margin goods; decisive on Ration Bars, whose true margin is
0.15. **Lesson worth keeping: a measurement that includes a transient is not a
measurement of the steady state**, and the tell was that every figure was high
rather than scattered.

**The capacity probe's window is counted in game-minutes, not ticks.** The same
mistake, arriving through the unit: a 200-*tick* settle is 3.3 game-minutes at
Phase 4's 1/60 rate and lands entirely inside that same ramp, which would have
inflated every manifest 2–15× the moment the rate was dialled down, with nothing
to say why. Caught by a test asserting the manifest is unchanged at
`economyRate` 1/60.

**A quota is a ledger, not a snapshot** — already decided above, now measured.
Stores, population and every chain throughput are identical to four decimal
places at cadences of 96, 168, 240, 360 and 600 game-minutes, and every cycle
settles at fill 1.0000. Interval length has no economic effect at all, which is
exactly what the cadence bands require.

**Delivery is paced by schedule, not by a per-tick rate cap.** Identical in
steady state, but it can clear a backlog after a lull, and — critically — it can
never run *ahead*. **Rejected:** a lead allowance letting the dock collect early.
Measured with 25% lead at a 2,880-minute cadence, Alloy Tools sits at zero for
2,160 game-minutes, Settler happiness goes to zero and the colony dies of
attrition. Running ahead empties a store, completes the line partway through the
cycle and leaves the rest of the interval with no sink.

**One clock.** `tickCount` is the only measure of elapsed time; the ledger
carries deliveries and nothing else, and the quota owns its own tick window.
**Rejected:** leaving the ledger's own `elapsedMinutes` alongside `tickCount` —
that is the exact shape of §18 S7, where `Colony.gridFactor` re-derived what the
allocator had already computed and the two agreed only by coincidence of reading
the same inputs.

**The stipend is paid per shipment, not per settlement.** The brief's formula was
a flat figure per cycle, but cadence changes with the band, so a flat figure is
at its mercy: income per game-minute would have run 0 / 1.25 / 1.25 / 1.00 / 0.75
from Receivership to Patron, and **Patron would have paid 40% less per hour than
Indifferent** — the exact opposite of §4.1's "bonus stipend". Scaling by the
cadence the shipment covers makes income per game-minute exactly the band
multiplier. This is the demand-rate invariant in mirror image, and the general
rule is worth stating once: **anything expressed per settlement is distorted by
cadence.**

**The stipend is paid before Standing moves.** The goods left under the posture
the Empire held during that cycle, and that was the price on offer. Paying
afterward would let a collapse into Receivership retroactively confiscate the
shipment just made. Symmetrical with the cadence lag — a band change shapes the
manifest *announced* at settlement, never the one promoted, because an announced
manifest that changes under you is worthless to retool against.

**The reserve floor binds the Empire, not the colonists.** `Population.applyTick`
runs before production and before delivery, so colonists draw first and are not
floor-limited — they must not be, or they would starve with food in the
warehouse. Measured at load 4.0, water reaches 42 against a floor of 60 and
oxygen 9.1 against 60, every unit of it a colonist eating, while the Empire's own
draw crosses the floor zero times in 3,000 ticks. The floor itself is re-confirmed
as load-bearing: without it, load 3.0 ends at 108 colonists instead of 206 and
load 4.0 ends at zero instead of 101. The reserved set is now *derived* from
`ColonistTier.basicNeeds` rather than hand-listed, so a tier gaining a basic need
in Phase 5 protects that good automatically.

**A commission is pass or fail, and sized from storage headroom.** A quota is
graded because you had no say in it; a commission is a bet you chose, so 99%
delivered pays what 0% pays. **Rejected,** both measured and both degenerate:
sizing from *flow*, which is unmeetable at load 1.0 because the quota already
takes 100% of capacity; and sizing from *current stock*, which is always met and
eats the entire buffer in one go, after which every later contract is worth
nothing because the buffer never regrows.

**The sink has to be permanent, and settlement is what makes it so.** Recorded
because it was shipped broken and caught by test: a completed manifest has no
collectable allowance left, so without a cycle rollover the Empire stops
collecting at the end of the first interval. Whatever replaces a sink has to
drain forever, the way the thing it replaced did.

### Working method — Phase 2 (13 Oct 2026)

**"Full files, never elided" is not a style preference, and Phase 2 paid for
re-learning it.** Step 7 was handed over as a dozen dispersed block edits to
five files instead of complete files; nine compile errors followed, every one of
them a block that had not landed — a missing method, an initialiser that never
got its new parameters, a struct closed early. §22 already said this, twice, with
two prior incidents attached. It is now said a third time with a third.

### Explicitly not taking

From `OGAME_COMPARISON.md` §4:

- **Dark Matter, officers, classes** — monetisation and account-level modifiers
- **Flat, chainless production** — Helios's chains are strictly more interesting
- **Points-as-raiding-target** — take the score, design against the distortion
- **Twelve-hour build times** — adopt the exponential *shapes*, not the durations
- **Deep combat minutiae** (the 1% shield bounce rule and similar)
- **Closed-form offline solving** — impossible here

### Documentation (28 Aug 2026)

**One master document.** `HELIOS_DESIGN.md`, `HELIOS_ROADMAP.md` and
`HELIOS_WORLD.md` are superseded by this file and reduced to stubs. Research inputs
(`OGAME_COMPARISON.md`, `sources/`) stay as inputs and are never authoritative.
Point-in-time artefacts (audits) are dated and archived.

**Recorded drift, now corrected:** the old design doc claimed Phase 0 complete with
Phase 1 next when most of Phase 1 had landed; described `ChainStatus` as a
three-case enum; described a per-chain "stall → input → run" tick that no longer
exists; said "nine-chain seed network" when there are ten; claimed Refined Alloy
nets ~+2/min when Cell Factory made it structurally short; listed `PlanetBackdrop`
under `Shared/`; and omitted `energyProduced`, `energyRequired`, `workforceAssigned`,
`workforceRequired`, `requiredTier` and `throughput` from the `ChainDetail` table.

---
---

# Part VII — Working method & gotchas

## 22. Working method

- **UI-first.** Visual and state layers first; simulation logic plugs in behind.
- **Manual implementation.** Claude provides complete, pasteable code blocks;
  Bernat pastes them in and verifies a clean build at each step.
- **Decisions before implementation.** Options with trade-offs, an explicit choice,
  rationale recorded — including rejected alternatives — before code.
- **Unify early.** Duplicated or parallel models get merged while it's cheap. This
  has paid off three times.
- **Full files, never elided.** Handing over a rewrite with `...unchanged...`
  comments has twice caused a stripped-down screen to be pasted in, and lost
  `PlanetBackdrop` from `MainColonyView` for several phases.
- **Commit more often.** Three weeks of work sat uncommitted before 28 Aug — one
  commit in the repo's entire history until then. A private GitHub remote was
  added the same day (`origin`, personal account via the `github-personal` SSH
  alias), so the work is no longer on a single disk. Push as you go.

## 23. Gotchas

**Glow/blur must be framed.** Effects extending past a view's frame need an explicit
outer `.frame()`, or they silently inflate the parent's layout width. Caused a
full-width-stretch bug via `PlanetBackdrop`'s atmosphere glow.

**Silent navigation failure.** A `NavigationLink(value:)` whose type has no
registered `.navigationDestination` fails silently — no crash, no warning, just a
dead tap. "Tapping does nothing" is almost always a value/destination **type
mismatch**. Note `ChainDetail.ID` is currently registered in two places (§18 S14).

**`let` as the first statement in a `ForEach` closure** breaks type inference; the
compiler falls back to the `Binding<C>` overload. Extract the row into an
`@ViewBuilder` method.

**Explicit `return` in a `#Preview`** is a result-builder error. `let x = ...`
followed by a bare view expression is fine; `return` is not.

**`Material` vs `ShapeStyle` in ternaries.** Both branches must be the same concrete
type. Wrap in `AnyShapeStyle(...)`.

**Easy-to-miss imports.** `Timer.publish` needs `Combine`; `TimeInterval` in a file
importing only `Observation` needs `Foundation`.

**Live-lookup ids must come from live state.** A preview passing
`ChainDetail.sample.id` won't match the *copy* inside `GameState.seeded()`. Take the
id from the injected state.

**Dormant enum cases rot.** `.docked` was kept in seed data so its label/tint stayed
exercised — then seed data changed and that path went untested. `.paused` and
`LimitReason.workforce` are now in the same condition. Verify fresh when activating.

**Randomness in a SwiftUI `body` re-rolls on every evaluation — and so does
randomness in a plain `let` computed in `init`.** A view struct is reconstructed
(`init` re-run) every time its parent's body re-evaluates, not only when its own
`body` is read. Only `@State`'s persistent, identity-keyed storage survives that
reconstruction. Caught by testing on device, not by review. See §18 S12.

---
---

# Appendices

## Appendix A — OGame transfers: taken, deferred, rejected

Condensed conclusions. Full analysis, formulas and trade-offs in
`OGAME_COMPARISON.md` — a **dated research input**, not authoritative.

| Mechanic | Verdict | Where |
|---|---|---|
| Production factor (energy throttle) | **Taken** | §9 — built |
| Universal proportional allocation | **Taken** (option B) | §8 — built |
| Two pacing multipliers | **Taken** | §14 — built |
| Per-mine output % | **Taken** | Phase 1a — built |
| Loading is a withdrawal | **Taken** | Phase 3 |
| Levels, `1.1`/`1.5` exponents | **Taken**, on `Building` | Phase 5 |
| Fields → plot cap | **Taken**, as Writs | Phase 5 |
| Storage as levelled building | **Taken** | Phase 5 |
| World position/temperature → modifiers | **Taken** as world types | Phase 5 |
| Points/score | **Taken**, as Standing | Phase 6 |
| Population as a gate | **Taken** | Phase 6 |
| People stay, goods move | **Taken** | §10 |
| Offline catch-up | **Taken as replay**, not closed form | Phase 4 |
| `t ∝ √distance` | **Deferred** — only if world distances span an order of magnitude | Phase 3 |
| Speed slider + fuel | **Deferred** | Phase 3 |
| Combat resolver | **Deferred**, take near-verbatim | Phase 8 |
| Raiding / bounded loss | **Taken bounded** | Phase 8 |
| Debris fields, moons, expeditions, fleet save | **Not taken** — noted as emergent-design lessons |  |
| Flat chainless production | **Rejected** |  |
| Dark Matter, officers, classes | **Rejected** |  |
| Points-as-raiding-target | **Rejected** | §4.1 |
| Twelve-hour build times | **Rejected** — shapes, not durations |  |
| Deep combat minutiae | **Rejected** |  |

**The transferable lesson**, worth more than any single mechanic: the systems most
worth adding are the ones that *interact* with what already exists. OGame's fleet
save was never designed — it emerged from two rules meeting. Helios's colony pool
produced emergent chain interlinking the same way. By that test, energy throttle,
plot cap, "loading is a withdrawal" and now **quota** score highest; combat and
trade routes score lowest, because they run parallel to the economy rather than
changing it.

## Appendix B — Document map

### In this repo (`Helios/`)

| File | Status |
|---|---|
| **`HELIOS.md`** | **Authoritative.** This file. |
| `HELIOS_DESIGN.md` | ⚠️ Superseded stub → this file. Full text in git history. |
| `HELIOS_ROADMAP.md` | ⚠️ Superseded stub → this file. Full text in git history. |
| `HELIOS_WORLD.md` | ⚠️ Superseded stub → this file. Full text in git history. |
| `OGAME_COMPARISON.md` | 📚 **Reference input**, Aug 2026. Not authoritative. Conclusions live in Appendix A. Keep for its formulas and the combat spec. |
| `DOCS.md` | Map of what's authoritative and what isn't. |
| — | 📌 `AUDIT-2026-08-28.md` lives in the **Claude project**: a point-in-time snapshot valid only for commit `e5ae9ca`. Its findings are folded into §18, which is the live status. |

### The reference library (`sources/`, 31 files)

The **Anno 1800 reference library** — a restructured Steam guide covering
progression, economy, logistics, production chains, regions, DLC, ships, combat,
specialists, and optimisation. Pure external reference material about a *different
game*. Useful for mining mechanics; nothing in it describes Helios.

✅ **Moved into the repo 28 Aug 2026.** It previously sat at `Helios/sources/`,
a sibling of the repo at `Helios/Helios/` — untracked and unbacked-up. It is now
inside the work tree and version-controlled.

Note it is large (~13,000 lines across 31 files) and completely static. It will
never change again, so it costs one commit and nothing thereafter; treat any diff
touching it as suspicious.

### In the Claude project

| Project doc | Status |
|---|---|
| `claude/HELIOS.md` | 🔁 Mirror of this file. **The repo copy is canonical.** Re-sync on material change. |
| `claude/AUDIT-2026-08-28.md` | 📌 Dated snapshot, commit `e5ae9ca`. |
| `claude/HELIOS_DESIGN.md`, `HELIOS_ROADMAP.md` | ⚠️ Superseded stubs. |
| `OGAME_COMPARISON.md` | 📚 Reference input. |
| 31 Anno 1800 docs | 📚 Reference input. |

✅ **Resolved 28 Aug 2026.** The project had held two documents at the path
`HELIOS_DESIGN.md` (12 Aug and 20 Aug). Path lookups always resolved to the newest,
so the 12 Aug draft was invisible to read and write — but reachable through project
*search*, which is how it was recovered and inspected. It was an earlier draft of
the same document, superseded in every respect but three details that the 20 Aug
rewrite had dropped. Those three were rescued into this file first (the
glassmorphism reference material in §16, the `Motion` / per-world-palette rationale
for nested tokens in §16, and `SimulationCore` being JSON-driven in §14). Both
copies were then deleted and replaced with a single stub.

**Lesson worth keeping:** a document can be invisible to `project_read` and still
be live in search — and therefore still be answering questions with stale content.
Search is the way to audit a project for duplicates, not the file listing.

## Appendix C — Simulated balance baseline (28 Aug 2026)

Produced by a line-for-line Python port of `ProductionAllocator` and `Population`
run against `GameState.seeded()`. Scripts live in `tools/`; re-run them whenever
the chain network, resource capacities or population tuning change — **every
number below is a measurement of the current seed data, not a constant.**

### Export capacity ▲ corrected

Production net of colonist consumption at full population (300 Survivors + 150
Settlers), measured by `CapacityProbe` — the real allocator run on a sandboxed
copy of the colony with every chain forced to 100% output.

| Good | per game-minute | per game-hour | 28 Aug figure |
|---|---|---|---|
| Power Cells | 5.25 | 315 | ~~5.31~~ |
| Raw Ore | 5.00 | 300 | ~~5.09~~ |
| Alloy Tools | 2.75 | 165 | ~~2.80~~ |
| Oxygen | 2.25 | 135 | ~~2.31~~ |
| Raw Ice | 2.00 | 120 | ~~2.07~~ |
| Grain | 2.00 | 120 | ~~2.06~~ |
| Water | 0.50 | 30 | ~~0.56~~ |
| Ration Bars | 0.15 | 9 | ~~0.23~~ |
| Refined Alloy | **0.00** | 0 | ~~0.04~~ |

**Why the 28 August figures were wrong.** Every one of them exceeded the
arithmetic ceiling of the seed network at full population, by a near-constant
+0.06/min — the signature of a measurement averaged across the colony's
population ramp (248 → 450 colonists over ~90 game-minutes), when fewer
colonists were eating. The ceilings are checkable by hand and need no simulation
at all:

- **Ration Bars:** Synth 6.00 max − 3.60 (survivors) − 2.25 (settlers) = **0.15**
- **Water:** Reclaimer 12.00 − 6 (hydroponics) − 4 (synth) − 1.50 (settlers) = **0.50**
- **Oxygen:** Recycler 12.00 − 6.00 − 3.75 = **2.25**
- **Raw Ice:** 20 − 8 − 10 = **2.00** · **Grain:** 10 − 8 = **2.00** · **Raw Ore:** 15 − 10 = **5.00**
- **Power Cells:** 6 × 7/8 = **5.25** · **Alloy Tools:** 4 × 7/8 − 0.75 = **2.75**

**Refined Alloy is the structural bottleneck, and its true surplus is zero.** The
Smelter supplies 7/min while the Tool Fab and Cell Factory demand 5 + 3 = 8/min,
so both consumers sit permanently at **87.5%** and nothing is left to export. The
0.04 published in August was the debug sink's own draw, not production. This is
an accident of seed data rather than a designed constraint — but a *good*
accident: a legible, diagnosable bottleneck sitting exactly where the first
upgrade decision should go. Keep it, and make it deliberate.

Note how thin Water (0.50) and Ration Bars (0.15) are. Any quota naming them is
at the edge of what the colony can spare, which is why sizing must be per-good
rather than a single tonnage — and why the manifest generator refuses to name
any good below 0.05/min.

**These rates became the quota's rates.** `DebugSink` is gone; what it was
standing in for now does its job for real. Its hard-coded drain figures were the
August table, which means the Phase 1a sink was quietly running at an effective
load of ~1.02 — and 1.53 on Ration Bars. That accidental over-draw is what
produced the "stores settle at 3–7%" and "settler happiness 0.86" figures this
appendix used to report; neither survives at an honest load of 1.00.

### Steady state at load 1.0

| Chain | Throughput | Binding constraint |
|---|---|---|
| Ice Harvester | 100% | — |
| Ore Extractor | 100% | — |
| Power Plant | 100% | — |
| Water Reclaimer | 100% | — |
| Oxygen Recycler | 100% | — |
| Hydroponics Bay | 100% | — |
| Ration Bar Synth | 100% | — |
| Alloy Smelter | 100% | — |
| Alloy Tool Fab | **87.5%** | **refined-alloy** |
| Cell Factory | **87.5%** | **refined-alloy** |

Population stable at 450, every cycle settling at fill 1.0000. Stores (fraction
of capacity): raw-ice 0.48, raw-ore 0.30, power-cells 0.27, water 0.32, grain
0.15, oxygen **0.98**, ration-bars 0.58, refined-alloy 0.05, alloy-tools 0.46.

**Oxygen's full tank is understood, not accidental.** The seed colony starts at
248 Survivors and 0 Settlers and ramps to 450 over ~90 game-minutes; nobody eats
the ~200 units of oxygen that difference represents, which is exactly the
capacity of the tank, and at load 1.0 the Empire's draw equals net production so
nothing ever removes it. It is a survival buffer rather than saturation: the
Recycler runs at 100% (population eats before industry, which opens exactly
enough headroom each tick), nothing stalls, and the player's lever still works —
at 50% output, oxygen falls to 3% and population to 268. Sweeping it would cut
life-support slack from ~20 minutes to ~6, which is a worse colony for a tidier
number.

### Cadence is economically neutral

Measured over 3,000 ticks at each of the five cadences Standing actually uses:

| Band | Cadence | Settled fill | Population | Largest store delta vs 96 min |
|---|---|---|---|---|
| Receivership | 96 min | 1.0000 | 450 | — |
| Scrutinised | 168 min | 1.0000 | 450 | 0.0000 |
| Indifferent | 240 min | 1.0000 | 450 | 0.0001 |
| Favourable | 360 min | 1.0000 | 450 | 0.0000 |
| Patron | 600 min | 1.0000 | 450 | 0.0001 |

Largest throughput delta across all five: **0.0000**. Total demand is 19.9000 per
game-minute and Power Cells 5.2500 per game-minute at *every* band — identical,
not approximate, because a line is sized `capacity × interval × load` and the
interval cancels out of `line / interval`. The invariant is a property of the
formula rather than something a guard enforces, which means the way it breaks in
future is somebody editing the formula.

### The reserve floor, re-measured

| Load | Population with floor | Without floor | Settled fill with floor |
|---|---|---|---|
| 1.0 | 450 | 450 | 1.000 |
| 1.2 | 439 | 416 | 0.783 |
| 2.0 | 340 | 272 | 0.556 |
| 3.0 | **206** | 108 | 0.456 |
| 4.0 | **101** | **0** | 0.420 |

It costs deliveries to do it — fill at load 3.0 is 0.456 with the floor against
0.750 without — and that is the trade.

### Standing, measured

- **Hysteresis works:** sixteen cycles of fill oscillating 0.85/0.55 either side
  of the 0.75/0.65 threshold pair produce **zero** band changes, because the EMA
  parks reliability at 0.67–0.73, inside the gap.
- **A slope, not a switch:** four settled failures from Patron to Receivership;
  four perfect cycles from Receivership back to Indifferent.
- **Receivership has a floor:** 5,000 ticks on its 96-minute cadence leaves
  population at 450 under a load-1.0 manifest and 101 under a load-4.0 one.
- **And it is inert at load 1.0:** from the seeded start, Favourable after one
  settlement and Patron after two, with no path down. See §4.2.

### Commissions, measured

Over 4,800 ticks and 19 offers at load 1.0, with contracts sized from storage
headroom:

| Strategy | Accepted | Met | Quota fill | Reliability | Band |
|---|---|---|---|---|---|
| Ignore everything | 0 | — | 1.0000 | 1.0000 | Patron |
| Accept everything | 19 | 3 | 0.9663 | 0.9644 | Patron |
| Accept only what the stores already cover | **1** | 1/1 | 1.0000 | 1.0000 | Patron |

Accepting blindly costs −2.10 of direct Standing across those 19 offers. Playing
properly, **one offer in nineteen is worth taking** — because at load 1.0 the
colony has no spare flow and a contract can only be paid from a one-off buffer.
The feature is correct and inert, for the same reason Standing is.

### What quota does *not* fix

Quota moves the economy from saturated to flowing, but it cannot do it alone:

- **Breadth beats size.** A manifest naming one good unsticks one chain and
  leaves every other store saturated. The generator therefore names every good
  the colony can spare — eight of nine for the seed network.
- **The band is narrow.** Between "too small to matter" and "kills the colony"
  there is roughly a 0.75–1.2 load window, and fill ≈ `min(1, 1/load)` across it.
- **A second sink is still wanted, and Phase 2 made the case concrete rather
  than theoretical.** There is no load that gives both drained stores and spare
  capacity, because spare capacity *is* stores filling up. Without somewhere
  else for surplus to go, Standing pins at Patron and commissions go unaccepted.
  Construction consuming materials (Phase 5) is what gives the player a way to
  *spend* surplus deliberately rather than only having it taken. Quota is
  pressure; building is agency.
