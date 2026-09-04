# Implementation Brief — Phase 2: The Empire

**For a fresh implementation session.** Written 4 Sep 2026, after Phase 1.5.

**Read first:** `HELIOS.md` — §3 (core loop), §4 in full (the Empire: Standing,
Quota, Commissions, Writs), §18 (known issues), §19 (phases), **Appendix C**
(the measured balance baseline this phase is tuned against). This brief assumes
that context.

**Decisions here are settled, not options.** Where a choice was contested the
alternative is named with one line of rationale. If this contradicts `HELIOS.md`,
this is newer — update `HELIOS.md` and record it in §21.

This is the biggest phase so far: eight steps. It closes **S1** (the simulation
stops) and **S3** (credits only decrease), which are two of the three remaining
Critical issues.

---

## How to start the session

> I'm implementing Phase 2 of Helios, an iOS SwiftUI game. Read `HELIOS.md` for
> full context and `briefs/phase-2-the-empire.md` for what we're building. Work
> through the steps in order. For each step give me complete, pasteable files —
> never elided, never `// ...unchanged...`. I'll paste them in, build, run the
> tests, and tell you the result before we move on.

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

- **Build and test first, commit second.** The suite grows in almost every step
  below; "green" always includes it.
- **Commit even small steps.** Step 5 is a handful of lines. Commit it anyway.
- **If a step goes wrong, `git restore .` and retry** rather than patching
  forward from a broken state.
- **Use `git commit` — never `git commit --amend`.** In Phase 1a an accidental
  `--amend` folded ~15,000 lines of reference docs into a commit titled "Fix
  starfield". `--amend` is only for rewording the commit you *just* made, before
  pushing.
- `git push` is bare — upstream is set.

---

## Two decisions that must not be got wrong

### 1. Assessed capacity is *installed* capacity, not actual output

`HELIOS.md` §4.1 says quota scales with "assessed capacity (what you've built)."
Read that literally.

If quota scaled with what the colony *actually produces*, then turning a chain
down would lower next cycle's quota — and the optimal strategy becomes running
the colony at minimum. The player would learn to play with everything switched
off. That is the standing spiral again, arriving through a different door, and it
would poison the whole economy.

**So: assessed capacity is measured with every chain forced to `outputPercent = 1`.**
Throttling changes what you deliver *this* cycle, never what is asked of you next
cycle. Turning a chain down is a tactical choice with a real cost, which is
exactly what makes it interesting.

### 2. `tick()` still reads no clock

Quota deadlines are **tick counters, not `Date`s.**

`HELIOS.md` §14 requires the simulation step to be pure and clock-free — it is
what makes Phase 4's offline replay and Phase 9's server reconciliation possible,
and Phase 1.5 has a `tickIsDeterministic` test standing guard over it. A quota
that compares `Date()` inside `tick()` breaks all three.

Cadence is therefore expressed in **game-minutes**, and becomes real-world time
for free when Phase 4 dials `economyRate` to 1/60. At today's accelerated rate a
240-game-minute interval is 4 real minutes, which is convenient for development.

`HELIOS.md` §4.8 calls the cadence "real-time". That remains the intent; this is
how it gets there without building it twice or breaking determinism now. Record
the clarification in §21.

---

## Scope guard — NOT in this phase

- ❌ **Favour and Dispensations.** Deliberately deferred to Phase 5, when
  Dispensations give them a sink. Introducing a currency with a source and no
  sink is precisely how `credits` became S3. Commissions pay in **Standing and
  credits** for now.
- ❌ **Cargo / ships carrying the quota.** Phase 3. In this phase delivery is
  automatic from colony stores.
- ❌ Offline catch-up — Phase 4.
- ❌ Writs, plot caps, buildings, levels — Phase 5.
- ❌ `MainColonyView` redesign — Phase 6. Add a compact panel, don't restructure.
- ❌ Workforce as a throughput factor — Phase 1b, still open.

---

# The steps

---

## Step 1 — `CapacityProbe`: what this colony could produce

The number every quota is sized from. Pure, deterministic, no UI.

**Do:** run the real allocator in a sandbox rather than deriving a formula. Copy
the colony, force every chain to `outputPercent = 1`, run N ticks with a perfect
sink, and measure what accumulates. This is exactly the method that produced
`HELIOS.md` Appendix C, and it reuses the production code instead of duplicating
its rules in a second place that can drift.

```swift
struct CapacityProbe {
    /// Per-resource export capacity per game-minute: production at full output,
    /// net of what the colonists eat. Runs a *copy* of the colony — never
    /// mutates the live one.
    static func measure(colony: Colony, economyRate: Double, ticks: Int = 600) -> [Resource.ID: Double]
}
```

- Discard the first ~200 ticks so the sandbox settles before measuring.
- Deterministic: same colony in, same numbers out. No `Date`, no randomness.
- Not called per tick — once per quota generation.

**Sanity check against Appendix C:** for the seed colony this must return
approximately Power Cells 5.31, Raw Ore 5.09, Alloy Tools 2.80, Oxygen 2.31,
Raw Ice 2.07, Grain 2.06, Water 0.56, Ration Bars 0.23, Refined Alloy 0.04 per
game-minute. **If your numbers differ materially, stop and find out why before
continuing** — everything downstream is tuned against these.

**Files**
- new `Models/CapacityProbe.swift`
- `HeliosTests/` — new `@Suite("Capacity")`

**Tests**
- `matchesAppendixC` — seed colony, each value within ±5% of the table above
- `isUnaffectedByThrottling` — set three chains to 0.25, measure again, values
  unchanged. **This is the anti-exploit test.** It is the most important test in
  this step.
- `doesNotMutateTheColony` — stock, throughputs and statuses identical before
  and after

```
git commit -m "CapacityProbe: measure installed export capacity

Runs the real allocator on a sandboxed copy of the colony with every
chain forced to 100% output, rather than deriving a second formula that
could drift from ProductionAllocator.

Deliberately measures *installed* capacity, not actual output: if quota
scaled with what the colony currently produces, throttling would lower
next cycle's demand and the optimal play would be to run everything at
minimum. HELIOS.md §4.1.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 2 — The `Quota` model and its manifest

Still no delivery, no settlement — just the shape and how one is generated.

**Do:**

```swift
struct Quota: Codable, Hashable {
    let id: Int                      // monotonic, deterministic (see Step 4)
    let lines: [Resource.ID: Double] // named goods and amounts — the manifest
    let intervalMinutes: Double      // game-minutes, not wall clock
    let dueAtTick: Int               // absolute tick counter, never a Date
}
```

Generation, from `HELIOS.md` §4.2 "Sizing":

- Load factor **1.0** — the measured sweet spot. Below 0.75 it isn't a sink;
  above 1.2 it starts killing colonists (Appendix C).
- `amount = capacity[good] × intervalMinutes × load`, **per good at its own
  rate** — never one bulk tonnage. Water (0.56/min) and Ration Bars (0.23/min)
  are thin; a flat split would demand the impossible of them.
- **Breadth matters more than size.** Naming one good leaves stores at 97% full;
  naming all nine drops them to 73% at the same load (Appendix C). Name **at
  least five** goods per manifest.
- Never name a good whose capacity is below 0.05/min — that's Refined Alloy,
  structurally bottlenecked, and asking for it is asking for nothing.

**Files**
- new `Models/Quota.swift`
- new `Models/QuotaGenerator.swift`
- `HeliosTests/` — new `@Suite("Quota")`

**Tests**
- `manifestNamesAtLeastFiveGoods`
- `sizesEachGoodAtItsOwnRate` — the Water line is far smaller than the Power
  Cells line, in proportion to their capacities
- `neverNamesAStructurallyBottleneckedGood` — Refined Alloy never appears
- `generationIsDeterministic` — same colony and tick in, identical manifest out

```
git commit -m "Quota model and manifest generation

A quota is named goods and amounts, sized per good from its own measured
capacity — not a bulk tonnage. A manifest names at least five goods:
breadth is what unsticks the economy, not size (HELIOS.md Appendix C).

Deadlines are absolute tick counters, never Dates — tick() must stay
clock-free or Phase 4 replay and Phase 9 reconciliation both break.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 3 — Delivery: the ledger replaces `DebugSink`

**`DebugSink` is not deleted. It is replaced by the thing it was standing in
for.** Its drain loop, its per-good rates and — critically — its reserve floor
all become the quota delivery mechanism.

**Do:**

```swift
struct QuotaLedger: Codable, Hashable {
    var quotaID: Int
    var delivered: [Resource.ID: Double]
}
```

Each tick, for each line in the active quota, move up to
`lineAmount / intervalMinutes × economyRate` from stores into the ledger.

**This is a ledger, not a snapshot — the single most important mechanical
decision in the phase.** Deliveries accumulate across the interval; the Empire
never takes a photograph of your stores at the deadline. Measured (Appendix C):
under snapshot settlement, quota size is silently capped by *storage capacity*
rather than production — at a 960-minute interval the Power Cells line is 19×
everything the colony can physically hold, so it is unmeetable at any level of
industry. And because the interval lengthens as Standing improves, snapshot
settlement means **the better you play, the more impossible the quota becomes.**

Ledger delivery removes that completely: measured fill at intervals of 60, 240,
960 and 2,880 minutes is 0.59, 0.59, 0.60, 0.60 — interval length has **no
economic effect at all**, which is exactly what the cadence bands in Step 5 need.

**Keep the reserve floor.** Basic-need goods — `oxygen`, `ration-bars`, `water` —
may never be drawn below 30% of capacity. Without it, high load empties the
colony: at load 3.0 population ends at 192 with the reserve and **90** without;
at load 4.0, 89 with and **zero** without. Luxuries stay contested deliberately
(at load 1.0 settlers sit at 0.86 happiness because the Empire is taking their
Alloy Tools) — that contest is the intended squeeze.

Delete `Colony.applyTick(applyDebugSink:)` in favour of the quota path, and
remove `DebugSink.swift`. Update the Phase 1.5 tests that passed `sink:` — they
now drive delivery through a real quota instead.

**Files**
- new `Models/QuotaLedger.swift`
- `Models/Colony.swift` — delivery in `applyTick`, replacing the sink call
- **deleted** `Models/DebugSink.swift`
- `HeliosTests/HeliosTests.swift` — update the `sink:` helper and its callers

**Tests**
- `intervalLengthDoesNotChangeTheEconomy` — run at 60, 240 and 960 minute
  intervals; steady-state stock and throughputs match within tolerance. **This is
  the ledger's whole justification** — pin it.
- `basicNeedsAreReserved` — after 2,000 ticks at load 1.0, oxygen/rations/water
  each sit at 30% ±1% and population is ≈450
- `deliveryAccumulatesAcrossTheInterval` — the ledger grows monotonically and
  never exceeds the line amount

```
git commit -m "Quota delivery: a ledger, not a snapshot

Deliveries accumulate across the interval instead of the Empire
photographing your stores at the deadline. Snapshot settlement silently
caps quota size at storage capacity rather than production — at a
960-minute interval the Power Cells line is 19x what the colony can
hold — and since the interval lengthens with Standing, it would mean the
better you play the more impossible the quota becomes.

Measured fill across 60/240/960/2880-minute intervals: 0.59/0.59/0.60/
0.60. Interval length is now economically neutral, which is what the
cadence bands require.

Replaces DebugSink, keeping its reserve floor on basic-need goods:
without it, load 4.0 ends with a population of zero. HELIOS.md §4.2,
Appendix C.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 4 — Settlement, and the tick counter that drives it

**Do:**

- `GameState.tickCount: Int` — monotonic, **persisted**, incremented in `tick()`.
  This is the clock the whole Empire runs on.
- At `tickCount >= quota.dueAtTick`: compute `fill`, archive the result, promote
  `nextQuota` to current, generate a new `nextQuota`, reset the ledger.
- Fill is normalised per line so a big line and a small line count equally:
  `fill = Σ(delivered[g] / lineAmount[g]) / lineCount`.
- **The next manifest is published when the current one settles.** The player
  always has one full interval to retool. A quota you cannot see coming is a
  dice roll, not a decision (`HELIOS.md` §4.2).

**Files**
- `Models/GameState.swift` — `tickCount`, `currentQuota`, `nextQuota`, `ledger`,
  settlement in `tick()`
- `Models/GameSave.swift` + `Models/GameState.snapshot` — persist all of it
- `HeliosTests/`

**Tests**
- `settlementAdvancesToTheAnnouncedQuota` — the quota that becomes current is
  exactly the one that was `nextQuota` before settlement
- `nextQuotaIsAlwaysVisible` — `nextQuota` is non-nil at every point after the
  first generation
- `quotaStateSurvivesARoundTrip` — extend the Phase 1.5 `saveRoundTrips` test:
  tick past a settlement, save, load, and confirm the restored game settles at
  the same tick with the same manifest
- `tickIsStillDeterministic` — the Phase 1.5 test must still pass unchanged

```
git commit -m "Quota settlement on a persisted tick counter

GameState.tickCount is the clock the Empire runs on — an integer in the
save file, not Date. tick() stays pure and clock-free, which the Phase
1.5 determinism test guards.

The next manifest publishes the moment the current one settles, so the
player always has a full interval to retool.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 5 — Standing: reliability, bands, and cadence

**Do:**

```swift
enum StandingBand: Int, Codable, CaseIterable {
    case receivership, scrutinised, indifferent, favourable, patron
}
```

- `reliability: Double` — EMA over settled fills, `0.7 × old + 0.3 × fill`.
  Start at 1.0, band starts at `.indifferent`.
- Rise thresholds `[0.55, 0.75, 0.90, 0.97]`, fall thresholds
  `[0.45, 0.65, 0.82, 0.92]`. **The gap between them is the hysteresis** — bands
  must feel like a slope, not a switch.
- Cadence multiplier per band: receivership 0.4, scrutinised 0.7, indifferent
  1.0, favourable 1.5, patron 2.5 — applied to a 240-game-minute base.

**The rule that keeps this from becoming a death spiral:** falling Standing
shortens the interval and **shrinks each shipment proportionally** — total demand
per game-minute is unchanged. The Empire checks on you more often; it does not
squeeze harder. What you lose is planning horizon and attention. Get this wrong
and a bad cycle makes the next one harder, which is structurally identical to a
brownout throttling the power plant that would end it (`HELIOS.md` §4.1).

**Receivership has a floor:** it collects at the dock instead of paying (Step 6),
but never takes population, never takes buildings, and never cascades.

**Files**
- new `Models/Standing.swift`
- `Models/GameState.swift`, `Models/GameSave.swift`
- `HeliosTests/` — new `@Suite("Standing")`

**Tests**
- `failureNeverRaisesTheDemandRate` — settle ten cycles at fill 0 and assert
  demand *per game-minute* is the same at Receivership as at Indifferent. **The
  single most important test in this phase.**
- `bandsAreSticky` — oscillate fill either side of a threshold; the band must not
  flip every cycle
- `receivershipIsRecoverable` — from Receivership, deliver perfectly for N cycles
  and climb back to Indifferent
- `receivershipDoesNotKillTheColony` — 5,000 ticks at Receivership with no player
  action: population stays above zero
- `standingIgnoresColonySize` — a colony with half the chains but perfect
  delivery reaches Patron. Standing measures reliability, not size — this is what
  stops "stay small" being doubly rewarded once Standing is public (§4.1)

```
git commit -m "Standing: reliability bands with hysteresis and cadence

Standing is an EMA of delivered-over-demanded, banded from Receivership
to Patron with separate rise and fall thresholds so it reads as a slope
rather than a switch.

Falling Standing shortens the interval and shrinks each shipment
proportionally — total demand per game-minute never rises. Raising it on
failure would be self-reinforcing, structurally identical to a brownout
throttling the plant that would end it. HELIOS.md §4.1.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 6 — The Stipend (closes S3)

Small step, big consequence: `credits` finally has a source.

**Do:** on settlement, `credits += round(baseStipend × fill × bandMultiplier)`.

- Base stipend scaled so a met quota at Indifferent comfortably affords a
  Freighter (800 credits) every few cycles — the shipyard should become usable,
  not free.
- Band multipliers: patron 1.5, favourable 1.2, indifferent 1.0, scrutinised 0.7,
  **receivership 0.0** — at the bottom band the Empire collects at the dock and
  pays nothing. The goods still leave.
- Partial fill pays partially. Delivering 60% pays 60%.

**Files**
- `Models/Standing.swift` (multipliers), `Models/GameState.swift`
- `HeliosTests/`

**Tests**
- `metQuotaPaysAStipend` — credits strictly increase across a settled cycle
- `receivershipPaysNothingButStillTakesTheGoods` — credits unchanged, ledger
  still filled
- `partialDeliveryPaysPartially`
- `shipyardBecomesSustainable` — 20 cycles at fill 1.0 from the seed state
  affords at least two Freighters. **This is S3's regression test.**

```
git commit -m "Stipend: credits finally have a source (S3)

Paid on settlement, scaled by fill and Standing band. Receivership pays
nothing and still takes the goods — the Empire collects at the dock.

Before this, credits were mutated in exactly one place (credits -=) and
buying an Escort plus a Scout left the shipyard permanently unusable.
HELIOS.md §18 S3.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 7 — Commissions

The optional half, and the way out of Scrutinised.

**Do:**

```swift
struct Commission: Codable, Hashable {
    let id: Int
    let lines: [Resource.ID: Double]
    let deadlineTick: Int
    let standingReward: Double
    let creditReward: Int
}
```

- One offered at a time; `accepted: Bool`. Ignoring is always safe.
- Accepting and delivering pays credits and a **direct Standing bump** — this is
  the reconciliation path out of a bad band.
- Accepting and failing costs more Standing than never accepting.
- Because they are opt-in they can be **harder** than quotas without being
  unfair. This is where genuine difficulty spikes belong.
- Delivery uses the same ledger mechanism, with its own ledger.

**No Favour in this phase.** Commissions pay Standing and credits. Favour arrives
in Phase 5 alongside Dispensations, which give it a sink — introducing a currency
with no sink is how `credits` became S3, and doing it twice would be careless.

**Files**
- new `Models/Commission.swift`
- `Models/GameState.swift` — offer, accept, settle; `Models/GameSave.swift`
- `HeliosTests/` — new `@Suite("Commissions")`

**Tests**
- `ignoringACommissionCostsNothing`
- `failingAnAcceptedCommissionCostsMoreThanIgnoringIt`
- `commissionsCanLiftYouOutOfScrutinised`

```
git commit -m "Commissions: the optional half of the Empire's demands

One offer at a time, opt-in, delivered through the same ledger. Ignoring
is always safe; accepting and failing costs more than never accepting.
Because they are optional they can be harder than quotas without being
unfair, so this is where difficulty spikes belong.

Pays Standing and credits, not Favour — Favour waits for Phase 5, where
Dispensations give it a sink. A currency with a source and no sink is
exactly how credits became S3.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Step 8 — Surfacing it

The player currently cannot see any of this. Keep it compact —
`MainColonyView` is already crowded and its redesign is Phase 6.

**Do:**

- `QuotaPanel` on `MainColonyView`, below `PopulationPanel`: band name, time to
  deadline via `Format.duration`, and a progress bar of overall fill. Tappable.
- `QuotaDetailView` pushed from it: per-line rows — good icon, delivered / demanded,
  a bar, and stock on hand. Amber **only** on lines that will miss at the current
  rate; on-track lines stay neutral. Amber is reserved for alerts (`HELIOS.md` §16).
- The next manifest shown in a "Next cycle" section, so retooling is possible.
- Commission offer as a card with Accept / Ignore.
- Design tokens only, no raw literals. Reuse `FlowResourceCard` shapes where they
  fit rather than inventing new ones.
- Navigation payload is a typed wrapper, not a bare `Int` — same reasoning as
  `ChainID` in Phase 1.5.

**Files**
- new `Components/QuotaPanel.swift`, `Components/QuotaLineRow.swift`,
  `Components/CommissionCard.swift`
- new `Screens/QuotaDetailView.swift`
- `Screens/MainColonyView.swift`, `App/RootView.swift` (register the destination
  **once per stack**)

**Acceptance:** run for ten minutes. You can see what's owed, what you've
delivered, when it's due, and what's coming next. Throttling a chain visibly
changes a line's progress. Missing a quota visibly moves the band.

```
git commit -m "Quota, Standing and Commission UI

Compact panel on MainColonyView plus a pushed detail screen: per-line
delivered/demanded, stock on hand, and the next cycle's manifest so
retooling is possible. Amber only on lines actually off-track.

MainColonyView stays as-is structurally — its redesign is Phase 6.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN"
```

---

## Definition of done

- [ ] Eight commits, each green in build **and** tests, each pushed
- [ ] **S1 closed:** run 5,000 ticks with no player action — the economy never
      saturates, stores stay well below capacity, chains keep running
- [ ] **S3 closed:** credits rise across settled cycles; the shipyard is usable
      indefinitely
- [ ] Population survives 5,000 ticks at Receivership with no player action
- [ ] `tickIsDeterministic` still passes, unchanged
- [ ] `DebugSink.swift` is gone
- [ ] Force-quit mid-cycle and relaunch: same quota, same ledger, same deadline

## Then update the docs

In `HELIOS.md`: mark **S1** and **S3** resolved; tick Phase 2 in §19; record in
§21 the three decisions made here — **assessed capacity is installed capacity**,
**cadence is game-minutes until Phase 4**, and **no new currency without a sink**.
Note in Appendix C that the DebugSink rates became the quota rates. Re-sync the
Claude project copy. Commit as a ninth commit.

## Housekeeping to sweep in

Small, still-open, cheap to do while you're in these files:

- **S9** — move `ResearchCategory.icon` out of `Models/ResearchProject.swift`
  into `ModelStyles.swift`. The last model-purity violation, ~5 minutes.
- **`tools/` has drifted.** The Python harness still has `TOL = 0.001`, no
  `outputPercent`, and the pre-Phase-1a status rule. If you use it to re-tune
  quota numbers it will lie to you. Either update it to match
  `ProductionAllocator` or stamp it "valid as of Phase 1a" in its README.
- `HELIOS.md` Appendix B doesn't list `briefs/` or `tools/`; `DOCS.md` does.

## What Phase 3 will need from this

Phase 3 makes cargo real and turns delivery into actual ship movements. The
ledger is the seam: today it fills automatically from stores, then it fills when
a freighter arrives. Keep the delivery mechanism behind a single, narrow entry
point — one `deliver(_ good:_ amount:)` on the ledger — so Phase 3 swaps the
caller without touching settlement, Standing, or the UI.
