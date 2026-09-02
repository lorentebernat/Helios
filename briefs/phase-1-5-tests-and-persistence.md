# Implementation Brief — Phase 1.5: Lock the simulation down

**For a fresh implementation session.** Written 28 Aug 2026, after Phase 1a.

**Read first:** `HELIOS.md` — §8 (production), §14 (architecture, especially the
portability hedges), §18 (known issues), §19 (phases), Appendix C (balance
baseline). This brief assumes that context.

**Decisions here are settled, not options.** Where a choice was contested the
alternative is named with one line of rationale. If this contradicts `HELIOS.md`,
this is newer — update `HELIOS.md` and record it in §21.

---

## How to start the session

> I'm implementing Phase 1.5 of Helios, an iOS SwiftUI game. Read `HELIOS.md` for
> full context and `briefs/phase-1-5-tests-and-persistence.md` for what we're
> building. Work through the steps in order. For each step give me complete,
> pasteable files — never elided, never `// ...unchanged...`. I'll paste them in,
> build, run the tests, and tell you the result before we move on.

---

## ⚠️ The commit ritual — after every single step

**Every step ends with a green build, green tests, and a commit. Never two steps
in one commit.**

```bash
cd ~/Documents/Bernat/Development/Helios/Helios

git add -A
git status --short          # eyeball it — anything unexpected?
git commit -m "<the message given in the step>"
git push
```

- **Build and test first, commit second.** From Step 2 onward "green" includes
  the test suite. A commit with failing tests is worse than no commit.
- **Commit even trivial steps.** Step 1 is three small edits. Commit it anyway.
- **If a step goes wrong, `git restore .` and retry** rather than patching
  forward from a broken state.
- **Use `git commit` — not `git commit --amend`.** In Phase 1a an accidental
  `--amend` folded ~15,000 lines of reference docs into a commit titled "Fix
  starfield", and its message no longer describes its contents. `--amend` is only
  for deliberately rewording the commit you *just* made.
- `git push` is bare — upstream is set.

---

## Why this phase, and why in this order

Phase 1a shipped output % and left the simulation with **zero test coverage** on
its two most intricate pure functions. Everything in this phase is either a
refactor of those functions or a new consumer of them.

**Tests come before the refactors, not after.** Right now the correct values are
known and verified (Appendix C, and the Phase 1a acceptance run). Written after
the refactors, the tests would only assert whatever the refactored code happens to
do — which proves nothing. Written now, they will fail loudly if a refactor
changes behaviour.

Persistence lands last because it is the step that most benefits from everything
before it being nailed down, and because two things must be fixed *before* saves
exist or they poison every save file: `UUID()` identities that change on every
launch (S5, S14), and the question of what a save file is actually allowed to
contain (Step 5).

## Scope guard — NOT in this phase

- ❌ **Offline catch-up.** Persistence ≠ catch-up. On load, `lastTickAt` is set
  to *now* and elapsed real time is discarded. Replay is Phase 4.
- ❌ Quota, Standing, Stipend — Phase 2
- ❌ Workforce as a throughput factor — Phase 1b
- ❌ Buildings, levels, plots — Phase 5
- ❌ Removing `DebugSink` — it goes when Quota arrives

---

# The steps

---

## Step 1 — Three cleanups left over from Phase 1a

### 1a. The starfield jumps on every tab switch

`VoidBackground` uses `@State` for its 40 stars. `RootView` selects tabs with a
`switch`, so each tab is a **different view identity** — switching tabs tears the
subtree down and discards `@State`, generating a fresh starfield every time.
Stable within a screen, different between screens, and `VoidBackground` appears in
seven places. Before Phase 1a it re-rolled constantly so nobody noticed; now it
reads as a glitch.

The `@State` default expression also still runs its 40 randoms on every single
tick and throws them away.

**Do:** make it `private static let stars: [Star]` on the type. Generated once per
launch, shared by every instance, no per-tick work. The starfield is decorative
and identical everywhere — it does not want per-view identity.

**Rejected:** keeping `@State` and accepting the jump. It's a visible artefact in
the most-seen view in the app.

### 1b. `PlanetBackdrop` should be stable *per planet*

Different treatment, deliberately: a planet's surface *should* differ between
worlds, but a given world should look the same every time you open it. Today it
re-rolls whenever its `@State` is discarded.

**Do:** add a `seed: Int` parameter and generate the 14 blobs from a seeded
generator. Add `SeededGenerator` (SplitMix64, ~12 lines) conforming to
`RandomNumberGenerator` in `Shared/`.

Call sites pass a stable seed: `MainColonyView` passes
`game.activeColony.id.hashValue`, `DestinationCard` passes
`destination.id.hashValue`.

> `String.hashValue` is **not stable across launches** in Swift. That is fine
> here — within a launch a planet stays consistent, which is all this needs. If
> you ever want cross-launch stability, sum the UTF-8 bytes instead. Note it in
> a comment so nobody "fixes" it later by accident.

This generator is not throwaway: `HELIOS.md` §14 requires that any randomness in
the simulation be explicitly seeded, and Phase 8's combat resolver will need
exactly this type.

### 1c. Stale comments and a debug guard

- `ChainStatus.paused` — "wired in stage 1d" is done. Say what it means instead.
- `LimitReason.workforce` and `ChainDetail.workforceAssigned` — "stage 1c" is not
  a thing; they're waiting on **Phase 1b**. Reword.
- `DebugSink.enabled` is a bare `true`. Wrap it:
  `#if DEBUG static let enabled = true #else static let enabled = false #endif`
  It's temporary scaffolding that drains a colony; it must not survive into a
  release build by accident.

**Files:** `Shared/VoidBackground.swift`, `Backgrounds/PlanetBackdrop.swift`, new
`Shared/SeededGenerator.swift`, `Screens/MainColonyView.swift`,
`Components/DestinationCard.swift`, `Models/ChainStatus.swift`,
`Models/LimitReason.swift`, `Models/ChainDetail.swift`, `Models/DebugSink.swift`

**Acceptance:** switch tabs ten times — the starfield never changes. Open the same
destination twice — the planet looks identical. Open two different destinations —
they look different.

```
git commit -m "Cleanups after Phase 1a: stable starfield, seeded planets

VoidBackground's stars were @State, so switching tabs (a switch, hence a
new view identity) discarded them and re-rolled the field. Now a static,
generated once per launch.

PlanetBackdrop keeps per-planet variation but derives it from a seed, so
a given world looks the same each time it's opened. Adds SeededGenerator,
which HELIOS.md §14 requires for any simulation randomness and which the
Phase 8 combat resolver will reuse.

Also guards DebugSink behind #if DEBUG and fixes stale stage references."
```

---

## Step 2 — Make the sink injectable, then write the suite

The target is **Swift Testing** (`import Testing`, `@Test`, `#expect`), already
scaffolded in `HeliosTests`. Replace the placeholder `example()`.

### 2a. Injectable sink — do this first, it's why the tests can exist

Swift Testing **runs tests in parallel by default.** A mutable global
(`static var DebugSink.enabled`) toggled per test would be flaky in a way that
wastes hours. Do not do that.

**Do:** pass it in.

```swift
mutating func applyTick(economyRate: Double,
                        fleetRate: Double,
                        applyDebugSink: Bool = true) -> [ShipBuildOrder]
```

`GameState.tick()` passes `DebugSink.enabled`. Tests pass `true` or `false`
explicitly and never mutate shared state.

**Rejected:** a settable static (parallel-unsafe); a protocol-based sink
(over-engineering for something Phase 2 deletes).

### 2b. The suite

Group with `@Suite`. Build a fresh `GameState.seeded()` per test — never share.
A helper `func tick(_ g: GameState, _ n: Int, sink: Bool)` keeps them readable.

**Every expected number below was measured against the real allocator on 28 Aug
2026.** Use a tolerance of ±0.02 on throughputs and ±2 on populations.

| Test | Assert |
|---|---|
| `saturatesWithoutASink` | 300 ticks, `sink: false` → at least 8 chains `!= .running`, and mean store fill > 90%. This is S1, pinned so it can never be "fixed" silently. |
| `steadyStateWithSink` | 2,000 ticks, `sink: true` → **exactly two** chains not `.running`, both `.limited(.input("refined-alloy"))`, both throughput ≈ 0.86 |
| `sinkKeepsColonistsAlive` | same run → population ≈ 450; oxygen, ration-bars and water each at 30% ±1% of capacity (the reserve floor) |
| `outputPercentIsHonoured` | Tool Fab → 0.5, 2,000 ticks → throughput ≈ 0.5 **and status `.running`** (this is S15 — a chain at its requested rate is not limited) |
| `pauseStopsConsumption` | Tool Fab → 0, 2,000 ticks → status `.paused`, throughput 0, and refined-alloy stock > 100 (it accumulates because nothing draws it) |
| `throttlingFreesPower` | Power Plant `energyProduced` 90, all at 100% → Hydroponics ≈ 0.52. Pause Tool Fab + Cell Factory → Hydroponics ≈ 1.0. **This is S6** — under the old demand formula it would not move. |
| `noChainReportsLimitedWhileAtRate` | 2,000 ticks → for every chain, if `throughput / outputPercent >= 0.98` then status is `.running`. The general form of S15. |
| `gridFactorMatchesAllocator` | force a brownout → `colony.gridFactor` equals `supply/demand` clamped to 1, i.e. the value the allocator used. This is S7. |
| `populationDeclinesWhenStarved` | `Population` directly: zero oxygen, 100 ticks → count falls; needs met → count rises to capacity and stops |
| `promotionRequiresHappiness` | settlers with luxury unmet → happiness < 1 → no promotion into the tier above |

**Files:** `Models/Colony.swift`, `Models/GameState.swift`, `Models/DebugSink.swift`,
`HeliosTests/HeliosTests.swift` (or split into `AllocatorTests` / `PopulationTests`)

**Acceptance:** all tests green, suite runs in under a second, and `⌘U` passes
repeatedly (no parallel-execution flakiness).

```
git commit -m "Test suite over ProductionAllocator and Population

Ten tests pinning behaviour measured on 28 Aug 2026 (HELIOS.md Appendix
C): saturation without a sink, steady state with one, output % and pause
semantics, the S6 power-freeing case, the S15 status rule, and population
growth/decline/promotion.

Makes the sink injectable via Colony.applyTick rather than a mutable
static — Swift Testing runs in parallel and a shared toggle would be
flaky. HELIOS.md §18 S8."
```

---

## Step 3 — Slug ids for authored data (S14)

`HELIOS.md` §21 settled this in principle — "slug ids for authored data … a
regenerated UUID would orphan every reference" — and then `ChainDetail` and
`ResearchProject` kept using `UUID()` anyway. Fix it **before** saves exist, or
every save file orphans its navigation references on the next launch.

**Do:**

1. `struct ChainID: Hashable, Codable { let slug: String }` — a **wrapper, not a
   bare `String`**. `ChainDetail.ID` is a navigation payload; registering
   `.navigationDestination(for: String.self)` would collide with any other String
   route. Add `ExpressibleByStringLiteral` so seed data stays readable.
2. `ChainDetail.id` becomes `let id: ChainID`, hand-authored:
   `"ice-harvester"`, `"ore-extractor"`, `"power-plant"`, `"water-reclaimer"`,
   `"oxygen-recycler"`, `"hydroponics-bay"`, `"ration-bar-synth"`,
   `"alloy-smelter"`, `"alloy-tool-fab"`, `"cell-factory"`.
3. Same treatment for `ResearchProject.id` (`ResearchID`) — authored data too.
4. Add `static func blueprint(for: ChainID) -> ChainDetail?` looking up `samples`.
   Step 5 needs it.

**While you're in the navigation code — fix the duplicate registration.**
`ProductionListView` registers `.navigationDestination(for: ChainDetail.ID.self)`
itself, *and* `RootView` registers it on `MainColonyView` for tab 0. When
`ProductionListView` is pushed into tab 0's stack, that stack has two
registrations for the same type. Harmless today (last wins) but it's exactly the
shape of the "silent navigation failure" gotcha. Register it **once per stack**,
in `RootView`, and remove it from `ProductionListView`.

**Files:** new `Models/ChainID.swift`, `Models/ChainDetail.swift`,
`Models/ResearchProject.swift`, `App/RootView.swift`,
`Screens/ProductionListView.swift`, `Screens/ProductionDetailView.swift`

**Acceptance:** tests still green. Navigate Colony → chain detail, and
Production → chain detail; both work. `#Preview`s still resolve ids from injected
state, not from `samples`.

```
git commit -m "Slug ids for ChainDetail and ResearchProject

Authored data now uses hand-written slugs per the decision in HELIOS.md
§21, which UUID() had been quietly violating. Required before saves
exist: a regenerated UUID orphans every navigation reference on load.

ChainID is a wrapper rather than a bare String so navigation destinations
can't collide. Also registers the chain-detail destination once per
NavigationStack instead of twice in tab 0. HELIOS.md §18 S14."
```

---

## Step 4 — Randomness out of `tick()` (S5)

`GameState.tick()` constructs `Ship(...)` when a build order completes, and
`Ship.id = UUID()` executes inside what `HELIOS.md` §14 calls a pure step. It is
the one hedge in the portability list that the code violates.

**Do:**

1. `struct ShipID: Hashable, Codable { let serial: Int }`
2. `GameState.nextShipSerial: Int` — monotonic, part of saved state
3. `Ship.id` becomes `let id: ShipID`, assigned from the counter at construction
4. Seed ships get serials 1…5

`ShipNameGenerator.random()` stays as-is — it is called from `queueShip`, a UI
action, never from `tick()`. Add a comment saying so, because it looks like a
violation and isn't.

**Add a test:** `tickIsDeterministic` — two `GameState.seeded()` instances, queue
the same ship in each, tick 200 times, then assert identical stock, identical
throughputs, and identical ship ids. This is the property Phase 4's replay and
Phase 9's reconciliation both depend on.

**Files:** new `Models/ShipID.swift`, `Models/Ship.swift`, `Models/GameState.swift`,
`Models/ShipRouteTarget.swift`, `HeliosTests/`

**Acceptance:** determinism test green; the Fleet tab and route selection still
work.

```
git commit -m "Deterministic ship ids; no randomness inside tick()

Ship.id was UUID(), generated inside the pure simulation step — the one
Phase 0 portability hedge the code actually violated. Now a monotonic
serial carried in saved state.

Adds a determinism test: two identically seeded states, 200 ticks, must
produce identical stock, throughput and ids. Phase 4 replay and Phase 9
reconciliation both depend on this. HELIOS.md §18 S5."
```

---

## Step 5 — `Codable`, and the rule about what a save may contain

### The decision, settled

**A save file stores mutable state only. Authored data is rehydrated from the
registry on load.**

A chain saves its id, `outputPercent`, `throughput` and `status`. It does **not**
save its name, icon, rates, energy figures or required tier — those come from
`ChainDetail.blueprint(for:)`.

Why this matters more than it looks: if authored data is serialised, then
rebalancing a chain rate in a future build **will not reach anyone who already has
a save**. They keep playing the old economy forever, and you cannot tell from a
bug report. This is a standard and very expensive idle-game trap. The same applies
to `Destination`, `Resource`, and `ResearchProject`'s authored fields.

**Do:**

- Custom `Codable` on `ChainDetail`: encode `{ id, outputPercent, throughput,
  status }`; `init(from:)` looks up the blueprint by id and overlays them.
  **If the id is not in the registry, throw** — a chain that no longer exists
  should be dropped, not resurrected as a husk. `Colony`'s decoder catches that
  per-chain and skips it.
- Same shape for `ResearchProject` (id + status).
- Straightforward `Codable` for `ColonyStock`, `Population`, `TierPopulation`,
  `Ship`, `ShipBuildOrder`, `Colony`, and a `GameSave` wrapper.
- `ChainStatus` and `LimitReason` need `Codable` — they have associated values,
  so check the synthesised encoding round-trips.
- **`GameSave` carries `version: Int = 1`** as its first field. Cheap now,
  impossible to retrofit.

**Note:** this blueprint-overlay approach is an interim measure. Phase 5's
`Building` concept should split authored blueprint from runtime state properly.
Record that in `HELIOS.md` §21 so it isn't rediscovered as a surprise.

**Add tests:** `saveRoundTrips` — seed, tick 500, encode, decode, and assert the
decoded state ticks identically to the original for another 100 ticks.
`unknownChainIsDropped` — hand-craft a save naming a chain id that isn't in the
registry; decode succeeds with that chain absent.

**Files:** most of `Models/`, new `Models/GameSave.swift`, `HeliosTests/`

```
git commit -m "Codable over mutable state only

A save stores ids and mutable fields; authored data (names, rates, icons,
energy figures) is rehydrated from the registry on load. Serialising
authored data would mean a future rebalance never reaches anyone with an
existing save — and you'd never see it in a bug report.

GameSave carries a version field from day one. Unknown chain ids are
dropped rather than resurrected. Interim measure: Phase 5's Building
concept should split blueprint from runtime state properly."
```

---

## Step 6 — Actually saving and loading

**Do:**

- `SaveStore` in a new `Persistence/` group: JSON to
  `.applicationSupportDirectory/Helios/save.json`. Create the directory if absent.
  **Not `UserDefaults`** — this payload will grow, and `UserDefaults` is the wrong
  home for a document.
- Write **atomically** (`.atomic`), so a crash mid-write can't leave a truncated
  save.
- `GameState.load()` returns `GameState` — the saved one, or `.seeded()` if the
  file is missing, corrupt, or a version this build doesn't understand.
  **Never crash on a bad save.** Rename the bad file aside (`save.corrupt.json`)
  so it can be inspected rather than silently destroyed.
- Save on `scenePhase` → `.background` or `.inactive`, in `HeliosApp`.
- On load, set `lastTickAt = .now`. Elapsed real time is **discarded** —
  offline catch-up is Phase 4. Put that in a comment so it reads as a decision
  rather than an oversight.

**Acceptance:** run, throttle a chain to 25%, background the app, force-quit,
relaunch → the chain is still at 25% and stocks are where you left them. Corrupt
`save.json` by hand → the app launches into a fresh seeded game and leaves
`save.corrupt.json` behind.

```
git commit -m "Save and load to Application Support

Atomic JSON write on scenePhase background/inactive; load on launch with
fallback to a seeded game. A corrupt or version-mismatched save is moved
aside as save.corrupt.json rather than crashing or being destroyed.

Elapsed real time is discarded on load — offline catch-up is Phase 4,
deliberately not this. HELIOS.md §18 S4."
```

---

## Definition of done

- [ ] Six commits, each with a green build **and** green tests, each pushed
- [ ] `⌘U` passes repeatedly — no parallel-execution flakiness
- [ ] Force-quit and relaunch preserves throttle settings, stocks and population
- [ ] A hand-corrupted save launches cleanly into a new game
- [ ] The starfield never changes when switching tabs

## Then update the docs

In `HELIOS.md`: mark S4, S5, S8, S12 (fully), S14 resolved; tick Phase 1.5 in §19;
record in §21 the two decisions made here — **saves contain mutable state only**,
and **`ChainDetail`'s blueprint-overlay is interim, to be replaced by Phase 5's
`Building` split**. Re-sync the Claude project copy. Commit as a seventh commit.

## What Phase 2 will need from this

Quota settles on a real-time deadline, so it needs `lastTickAt` to be *saved* —
which it now is — and it needs a delivery ledger that survives a relaunch. If
anything in Step 5 makes that awkward, say so now rather than working around it
later.
