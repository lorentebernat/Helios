# Helios — Design & Decision Log

A space-colony strategy game for iOS, deliberately an **Anno–OGame hybrid**.
Anno 1800 is the systemic ancestor; OGame contributes specific mechanisms.
All terminology is original.

Companions: `HELIOS_ROADMAP.md` (phased plan, forward-looking) and
`OGAME_COMPARISON.md` (the transfer analysis the roadmap acts on).

**Status: Phase 0 complete.**

---

## 1. Working method

- **UI-first.** Visual and state layers first; simulation logic plugs in behind.
- **Manual implementation.** Claude provides complete, pasteable code blocks;
  Bernat pastes them in and verifies a clean build at each step. Claude Code is
  not used directly.
- **Decisions before implementation.** Options with trade-offs, an explicit
  choice, rationale recorded — including rejected alternatives — before code.
- **Unify early.** Duplicated or parallel models get merged while it's cheap.
  This has paid off three times (see §7).
- **Full files, never elided.** Handing over a rewrite with `...unchanged...`
  comments has twice caused a stripped-down screen to be pasted in, and lost
  `PlanetBackdrop` from `MainColonyView` for several phases.

### Prior art

An earlier headless `SimulationCore` Swift Package (`ProductionEngine`,
`TierEvaluator`, `SimulationClock`, 16 passing tests) exists as reference, not
active code. Its logic will eventually plug in at `ChainDetail.applyTick()` — and
the multiplayer plan makes reviving that separation genuinely necessary rather
than merely tidy (see §6).

---

## 2. Guiding principles

**Take OGame's mechanisms; keep Anno's centre of gravity.** Anno is a *flow*
game — value lives in throughput and interlocks. OGame is a *stock-and-exponent*
game. Levels and plots exist to make **choices** scarce, not numbers big.

**Offline accumulates; sessions decide.** At honest pacing, absence will always
out-produce a short session, so active play must not be *about* output. Absence
generates materials. Presence is where the player retasks chains, sets output
percentages, upgrades, and dispatches.

**Endless.** No win condition. Long-term motivation is asynchronous multiplayer.

---

## 3. Visual language

- Glassmorphism over a deep navy/void space background.
- `VoidBackground` = gradient + nebula glows + starfield.
- Cyan accent, ~RGB `0.30 / 0.85 / 0.95`.
- Amber (`GameTheme.warn`) reserved **strictly** for alerts and blocked states.
- Dark mode only.

### Design system

`DesignSystem.swift`, **nested-enum tokens** for scalability:

| Namespace | Members |
|---|---|
| `GameTheme.Spacing` | `xs, sm, md, lg, xl, xxl` |
| `GameTheme.Radius` | `chip, pill, row, panel, hero, tabBar, circleButton, iconBadge` |
| `GameTheme.GlassStroke` | `subtle, standard, prominent` |
| `GameTheme.Size` | `iconBadge` |
| `GameTheme.Font` | `label, caption, body, chipLabel, rowTitle, sectionTitle, heroValue, heroTitle, tabLabel` |

**Rule: reference tokens, never raw literals.** `.glass()` (backed by
`GlassPanel`) is the shared panel style.

`DesignSystem/ModelStyles.swift` holds every model→colour mapping as a view-layer
extension: `ChainStatus.tint`, `ShipStatus.tint`, `DangerLevel.tint`,
`WorldType.baseColor/bandColor`. **These deliberately do not live on the models**
— see §6.

`Shared/Format.swift` is the single source for display formatting:
`Format.decimal` (one decimal), `Format.integer` (locale-grouped),
`Format.duration(minutes:)` (`"3h:20:00"` / `"20:00"`).

---

## 4. Project structure

One struct per file; filename matches the type name.

```
App/            HeliosApp, ContentView, RootView
DesignSystem/   DesignSystem, ModelStyles
Shared/         VoidBackground, CircleGlassButton, GlassTabBar,
                PlanetBackdrop, Format
Models/         see §5
Components/     see §5
Screens/        MainColonyView, ProductionListView, ProductionDetailView,
                FleetView, ResearchView, RouteSelectView, BuildShipSheet
```

### Sample data convention

Static properties **on the model**, never the view: `sample` (single),
`samples` (collection), `sample<Variant>` (suffix, so autocomplete groups them).
These became `GameState`'s seed values rather than being deleted.

---

## 5. Architecture

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
| | `powerPercent` (placeholder) |

`Colony.ID == Destination.ID` — one colony per destination, so there's no
separate identifier to keep in sync. `Colony` resolves `name` and `worldType`
from the destination registry.

`Colony` is a **struct**: no Observation, no SwiftUI, so the simulation stays
portable. Views read through a non-optional `game.activeColony` computed
property — deliberately *not* proxy accessors on `GameState`, which would be a
facade hiding the structure.

`Colony.applyTick` **returns** completed `ShipBuildOrder`s for the empire to turn
into ships, because ships are empire-scoped and a colony can't create them.

**Constraint:** mutate array elements by index (`colonies[i].stock`,
`chains[i].status`), never wholesale-replace an element — replacement breaks the
stable identity navigation depends on.

### State

`@Observable` `GameState`, injected with `.environment(gameState)` at the app
root, read via `@Environment(GameState.self)`. `GameState.seeded()` is the seed
factory.

**Convention:** `GameState` holds game data; transient *view* state (filter
chips, sheet flags) stays local `@State`.

**Footgun:** any view reading the environment needs
`.environment(GameState.seeded())` in its `#Preview`, or it crashes.

### Navigation

Persistent tab bar: `RootView` owns `selectedTab` and hosts one
`NavigationStack` per tab, with a single `GlassTabBar` floating above so it
survives pushes.

- Tab roots (Colony, Fleet, Research) have **no** back chevron.
- Detail screens hide the native back button
  (`.navigationBarBackButtonHidden(true)`) and use a glass `CircleGlassButton`
  wired to `@Environment(\.dismiss)`.
- Payloads are `Hashable`: `ChainDetail.ID`, `ShipRouteTarget`,
  `ProductionListNav`.

### Game loop

`RootView` drives it with `Timer.publish` at `GameState.tickInterval`
(needs `import Combine`; `GameState` needs `import Foundation` for
`TimeInterval`).

Two pacing levers, split so they never have to be untangled:

- `economyRate` — production, population, research
- `fleetRate` — ship travel **and** shipyard build time

Both currently `1.0` (**accelerated**: one tick applies a full per-minute rate,
so one tick = one game-minute).

`tick()` is a **pure step that reads no clock**, so Phase 3 can replay it in a
loop. `advanceOneTick(now:)` wraps it and stamps `lastTickAt` — that's what the
timer calls. Order within a colony: **population eats first**, then production
chains, then the shipyard; ships advance at empire level afterwards.

---

## 6. Portability (the multiplayer constraint)

Asynchronous multiplayer in a shared persistent galaxy, **server-authoritative**,
is planned after Phase 7. This constrains code written now.

OGame can project resources client-side because its production is **linear**.
Helios cannot: the sim is **path-dependent** (chains stall and throttle,
population promotes and declines, energy and workforce will scale everything).
There is no closed form to interpolate. So the client will eventually run the
same simulation locally as a prediction and reconcile against server snapshots —
requiring the sim to be deterministic and identical on both sides.

**Hedges adopted in Phase 0**, all good hygiene regardless:

- `applyTick` logic lives in pure value types — no SwiftUI, no Observation.
  This is why colour mappings were moved out of the models into `ModelStyles`.
- `lastTickAt` stored rather than assuming continuous ticking.
- No randomness inside `tick()`. `ShipNameGenerator` is called from a UI action,
  not the loop; any future randomness must be explicitly seeded.
- `Destination` carries a `GalaxyCoordinate` (discrete `galaxy:system:position`,
  OGame-shaped) with a `distance(to:)` formula. **Not yet wired** — travel time
  is still authored per destination; Phase 2 switches to derived distance
  alongside fuel and the speed slider.

---

## 7. Game systems

### Production — a colony-wide pool

One stock per resource type per colony. Chains draw from it and deposit into it,
so interlinking is **emergent** rather than declared: no dependency graph, no
link management, no evaluation ordering.

| Type | Role |
|---|---|
| `Resource` | Static registry. Slug ids (`"refined-alloy"`), per-resource capacity. |
| `ColonyStock` | Value type. Deposit / withdraw / clamping. Withdrawals are all-or-nothing. |
| `ChainFlow` | A *requirement* (`resourceID` + `ratePerMin`), not a store. Resolves name/icon/capacity from the registry. |
| `ChainDetail` | A production chain. `applyTick` is the `SimulationCore` seam. |
| `ChainStatus` | `{ running, blockedInput(name), stalledOutput }` |

Per-chain tick: **stall check** (output pool full → halt, inputs preserved) →
**input check** (any input short → block) → **run** (consume, then produce).

Rates are stored as **positive magnitudes**; the `+`/`-` display sign derives
from input-vs-output position.

**The nine-chain seed network:**

```
Ice Harvester   ─┐
Ore Extractor   ─┤ extractors, no inputs
Power Plant     ─┘
                   ├─→ Water Reclaimer ──→ Hydroponics Bay
                   ├─→ Oxygen Recycler
                   ├─→ Ration Bar Synth
                   └─→ Alloy Smelter ────→ Alloy Tool Fab
```

The Tool Fab starts blocked (Refined Alloy at 0) and unblocks itself once the
Smelter delivers — auto-unblocking with no dedicated logic, as designed.

### Population — a distribution, not a pool

Five rungs, modelled as `[TierPopulation]`. A colony is a mixed society.

```
Survivors → Settlers → Engineers → Synthesists → Ascendant
```

| Type | Role |
|---|---|
| `ColonistTier` | Basic needs, luxury needs, `next`, `providesWorkforce`. |
| `PopulationNeed` | `resourceID` + `per100PerMin`. |
| `TierPopulation` | `count`, `capacity`, `happiness`, `basicNeedsMet`. |
| `Population` | The distribution, tuning, tick and promotion logic. |

| Tier | Basic | Luxury |
|---|---|---|
| Survivors | Oxygen 2.0, Ration Bars 1.2 | — |
| Settlers | Oxygen 2.5, Ration Bars 1.5, Water 1.0 | Alloy Tools 0.5 |
| Engineers+ | *placeholder* | *placeholder* |

Water is basic (survival), Alloy Tools luxury (quality of life) — split
deliberately so the happiness mechanic is exercised.

**Two severities:** basic unmet → colonists leave relatively fast
(`declinePerMin` 6.0). Luxury unmet → the tier is unhappy, which blocks promotion
*and* causes very subtle attrition (`unhappyAttritionPerMin` 0.5, scaled by
discontent).

**Happiness** is a 0–1 scale (fraction of luxury needs met), pinned at 1.0 for
tiers with no luxuries — so Survivors can never be unhappy and promote freely
once fed.

**Promotion** requires basic needs met, happiness 1.0, and free capacity above.
Evaluated highest-rung-first so nobody promotes twice per tick.

**Tuning:** `growthPerMin` 3.0, `promotionPerMin` 2.0.

**Visibility (progressive reveal):** active tiers render normally, the single
next rung renders dimmed, everything beyond is hidden.

### Fleet

| Type | Role |
|---|---|
| `Ship` | Transit data in **fields**: `locationID`, `destinationID`, `remainingMinutes`. |
| `ShipStatus` | Plain enum `{ idle, docked, inTransit }`, no associated values. |
| `ShipRole` | `freighter, scout, escort, explorer` + stats + build cost/time. |
| `ShipBuildOrder` | An entry in `Colony.shipyardQueue`. |
| `BuildCost` | `{ credits, materials: [MaterialRequirement] }` |
| `Destination` | Static world registry. Slug ids + `GalaxyCoordinate`. |

- Travel time = `destination.travelTimeMinutes / role.speedMultiplier`.
- Re-routing an in-transit ship is allowed.
- Arrival flips the ship to `.idle`, restoring the amber "wasted capacity"
  warning in `FleetSummaryStrip`.
- `.docked` is **fully dormant** — unreachable in code, unused by seed data.
  Reserved for "at a stop on an assigned trade route"; its label/tint path is
  untested until route automation lands.
- Construction: real queue, real build time, shown in an "Under Construction"
  section on `FleetView`. Costs are **deducted in full upfront** at queue time —
  credits from the empire, materials from the building colony's stock. The build
  sheet shows per-material have/need rows, amber when short.

**Ship material costs:**

| Role | Refined Alloy | Alloy Tools | Power Cells | Credits |
|---|---|---|---|---|
| Scout | 25 | — | 20 | 500 |
| Freighter | 40 | 10 | 25 | 800 |
| Escort | 60 | 25 | 40 | 1,200 |
| Explorer | 50 | 20 | 50 | 1,500 |

Refined Alloy starts at 0 and nets only ~+2/min, so nothing is buildable until
the Smelter has run for a while. Deliberate tension.

### Research

`ResearchProject` with `{ locked, available, inProgress, completed }`, filtered
by `ResearchCategory` chips. Empire-scoped; the global/local split is a Phase 5
decision. Points are generated by Ascendants (not "Scholars" — Anno's term).

**Known gap: research does not tick.** `researchRatePerMin` is 12 but
`researchPoints` never changes. A dead system awaiting Phase 5.

---

## 8. Decision log

Decisions that shaped the codebase, with rationale and rejected alternatives.

### Design tokens: nested enums over flat statics
Nested namespacing keeps autocomplete organised as categories grow, rather than
producing one long flat list.

### Sample data on the model, not the view
A view shouldn't need to know what example data looks like. Surfaced when
`ChainDetail.sample` and `ProductionDetailView.sample` diverged and only one
worked with leading-dot shorthand.

### Unify parallel models early
`ProductionChain` (summary) and `ChainDetail` (full) were linked by
`matching(name:)` — a string lookup with nothing enforcing consistency. Unified
at three chains, when it was cheap. **Rejected:** link-by-ID (still two objects
to sync), defer (bakes the fragility deeper).

### Enum over nullable string for state
`ChainStatus` replaced `missingInputName: String?`; `ShipStatus` dropped its
associated values in favour of fields. A thing is in exactly one state — don't
infer it from whether a string happens to be nil. Applied twice.

### Slug ids for authored data
`Destination.ID`, `Resource.ID`, and `MaterialRequirement.resourceID` are
hand-written strings, not UUIDs. Seed data can reference them, they're debuggable
in logs, and they survive save/load — a regenerated UUID would orphan every
reference. This also killed a casing-mismatch bug (`"KEPLER OUTPOST-7"` vs
`"Kepler Outpost-7"`) by deriving names from the registry.

### Colony pool over chain-to-chain links
Interlinking is emergent. This also **killed the struct-vs-class question** for
`ChainDetail`: with a pool there are no shared mutable resource objects, so
chains stay structs and navigation is undisturbed.

### Components stay pure functions of their inputs
`FleetView` resolves destination names and passes them into `ShipRow`; `ShipRow`
does not read the environment. This is why `FleetSummaryStrip` needed zero
changes across three migrations.

### Population eats before industry
Colonists win contested resources, so shortages surface as *blocked production* —
diagnosable — rather than as silent population decline. Revisitable.

### Shipyard queue per colony, ships per empire
A queue is a *shipyard* — a building at a place, as in both OGame and Anno. Ships
move between colonies once built, so they belong to the empire. This also gives
"which colony's materials pay for this?" an answer.

### `tick()` reads no clock
Timestamping lives in `advanceOneTick(now:)`. Keeping the simulation step pure is
what makes Phase 3's replay-based offline catch-up possible.

---

## 9. Open work

See `HELIOS_ROADMAP.md` for the phased plan. Immediate:

### Phase 1 — unified throughput (next)
Energy as a live per-colony balance, workforce actually staffing chains,
player-set output % per chain, one combination rule, `throughput: Double`
alongside `ChainStatus`.

**Workforce carries the critical rule:** when colonists advance a tier they
*stop* providing the previous tier's workforce, so every tier must be maintained.
Promoting everyone upward starves lower-tier industry. This is the Anno squeeze
and is central, not optional.

**Note:** energy producers are themselves chains. Compute the factor from the
previous tick's running set, or exempt producers from their own throttle, or a
brownout becomes self-reinforcing.

### Polish
- **Redesign `MainColonyView`.** It's packed, and Phase 1 adds a Grid readout
  plus throughput badges. Deferred to Phase 5 in the roadmap, but the pressure is
  already visible.

### Deferred / to design
- **Category chips** on `MainColonyView` and `ResearchView` will be revisited and
  possibly repurposed. Colony's chips (Power/Storage/Habitat/Defense/Life
  Support) are a **building** taxonomy and remain cosmetic — Phase 4 gives them a
  job. `CategoryChip` takes `fillsWidth: Bool`; Colony passes `true`.
- **Ellipsis menus** get different per-screen actions (colony: rename, abandon).
- **Tier 3–5 needs** and more Settler food categories, with the fuller resource
  network. Ascendant provide **no** workforce.
- **Compact number notation** (`1.2M`, `3.4B`) when numbers actually grow.

### Known simplifications
- **Scarcity is crude.** Binary halt, first-come-first-served by array order.
  Array order silently determines who starves. Phase 1 replaces this with
  universal proportional allocation.
- **Display-only ship stats.** `cargoCapacity`, `shields`, `weapons` are invented
  placeholders with no gameplay effect; only `speedMultiplier` functions.
  **Standing rule: everything the ship UI displays must be implemented for real
  at some point.** A commitment, not decoration. Cargo lands in Phase 2, combat
  stats in Phase 7.
- **The economy sits near a knife edge** at full population capacity.
  Oscillation between running and blocked is a balance signal, not a bug.

---

## 10. Gotchas

**Glow/blur must be framed.** Effects extending past a view's frame need an
explicit outer `.frame()`, or they silently inflate the parent's layout width.
Caused a full-width-stretch bug via `PlanetBackdrop`'s atmosphere glow.

**Silent navigation failure.** A `NavigationLink(value:)` whose type has no
registered `.navigationDestination` fails silently — no crash, no warning, just a
dead tap. "Tapping does nothing" is almost always a value/destination **type
mismatch**.

**`let` as the first statement in a `ForEach` closure** breaks type inference; the
compiler falls back to the `Binding<C>` overload and reports
`Cannot convert value of type '[X]' to expected argument type 'Binding<C>'`.
Extract the row into an `@ViewBuilder` method.

**Explicit `return` in a `#Preview`** is a result-builder error. `let x = ...`
followed by a bare view expression is fine; `return` is not.

**`Material` vs `ShapeStyle` in ternaries.** Both branches must be the same
concrete type. Wrap in `AnyShapeStyle(...)`.

**Easy-to-miss imports.** `Timer.publish` needs `Combine`; `TimeInterval` in a
file importing only `Observation` needs `Foundation`.

**Live-lookup ids must come from live state.** A preview passing
`ChainDetail.sample.id` won't match the *copy* inside `GameState.seeded()`. Take
the id from the injected state.

**Dormant enum cases rot.** `.docked` was kept in seed data so its label/tint
stayed exercised — then seed data changed and that path went untested. Verify
fresh when activating.
