# Implementation Brief — Phase 1a: Output %, and making the economy observable

**For a fresh implementation session.** Written 28 Aug 2026 against commit
`e5ae9ca` + the docs consolidation.

**Read first:** `HELIOS.md` — especially §8 (production), §9 (energy), §14
(architecture), §18 (known issues), §19 (phases), Appendix C (balance baseline).
This brief assumes that context and does not repeat it.

**Decisions in this brief are settled, not options.** Where a choice was
contested, the rationale is one line and the alternative is named. If something
here contradicts `HELIOS.md`, this brief is newer — update `HELIOS.md` and record
it in §21.

---

## How to start the session

Paste this:

> I'm implementing Phase 1a of Helios, an iOS SwiftUI game. Read `HELIOS.md` for
> full context and `briefs/phase-1a-output-percent.md` for what we're building.
> Work through the steps in order. For each step give me complete, pasteable
> files — never elided, never `// ...unchanged...`. I'll paste them in, build,
> and tell you the result before we move on.

---

## ⚠️ The commit ritual — after every single step

**Every step ends with a clean build and a commit. No exceptions, and never two
steps in one commit.**

```bash
cd ~/Documents/Bernat/Development/Helios/Helios

git add -A
git status --short          # eyeball it — anything unexpected?
git commit -m "<the message given in the step>"
git push
```

Rules:

- **Build first, commit second.** A commit that doesn't compile is worse than no
  commit — it destroys the ability to bisect.
- **Commit even one-line changes.** Step 1 is four lines. Commit it anyway.
- **If a step goes wrong, `git restore .` and retry** rather than patching
  forward from a broken state. That is the entire reason for committing this
  often.
- **Never batch.** "I'll commit when the feature's done" is how three weeks of
  work ended up uncommitted in August.
- `git push` is a bare push — upstream tracking is already set to `origin/main`
  on the personal account.

If a step turns out to need more than one build-and-verify cycle, that's fine —
commit at the last green state before continuing.

---

## Why a debug sink comes before the feature

**Measured, not assumed** (`HELIOS.md` Appendix C, `tools/`):

In the current build the economy saturates by ~tick 60 and every store sits at
capacity. Under those conditions, **output % has no observable effect at all**:

| Alloy Tool Fab set to | Refined Alloy stock | Alloy Tools stock | Cell Factory |
|---|---|---|---|
| 100% | 149/150 | 150/150 | 0% |
| 50% | 149/150 | 149/150 | 0% |
| 0% | 150/150 | 0/150 | 0% |

Throttling changes which store is full, and nothing else. You would build the
feature correctly and be unable to tell whether it worked.

So Step 3 adds a **temporary debug sink** — a developer-only drain that pulls
goods out of the colony each tick. It exists to make Phase 1 testable and feelable,
and **Phase 2 deletes it** when the real Quota lands. It is scaffolding, and it is
labelled as scaffolding in the code.

With a sink present, throttling works exactly as intended and the numbers become
legible: eight of ten chains run at 99–100%, and the Refined Alloy contention
between the Tool Fab and the Cell Factory becomes visible and actionable.

---

## Scope guard — what this phase is NOT

Do not build any of these now, however tempting:

- ❌ Quota, Standing, Stipend, Commissions — that's Phase 2, and it needs
  persistence first
- ❌ Workforce as a throughput factor — the second half of Phase 1, separate
- ❌ Persistence / `Codable` — Phase 1.5
- ❌ Buildings, levels, plots — Phase 5
- ❌ Redesigning `MainColonyView` — Phase 6

If a step tempts you into one of these, stop and note it instead.

---

# The steps

---

## Step 1 — Stop the starfield re-rolling (S18 → S12)

**Warm-up. Four lines. Establishes the rhythm.**

`VoidBackground` calls `Double.random` / `CGFloat.random` inside `body` for 40
stars; `PlanetBackdrop.surfaceTexture` does the same for 14 ellipses. Since the
tick loop mutates observable state every second, any re-evaluation reshuffles
them.

**Do:** generate the values once into a `let` array built in `init()` (or a
`@State` initialised once), and read from it in `body`. A small `struct Star {
x, y, size, opacity }` is clearer than four parallel arrays.

**Don't** use `@State private var stars = (0..<40).map { ... }` and assume it's
stable — it is, but the intent reads better with an explicit initialiser.

**Files:** `Shared/VoidBackground.swift`, `Backgrounds/PlanetBackdrop.swift`

**Acceptance:** run in the simulator for 30 seconds with the tick loop active.
Stars must not twinkle, jump, or re-scatter. The planet's surface blobs must stay
put as it rotates.

```
git commit -m "Fix starfield and planet texture re-randomising every tick

Random values were generated inside body, so any re-evaluation reshuffled
them. Now generated once at init. HELIOS.md §18 S12."
```

---

## Step 2 — One source of truth for the grid factor (S7)

Two different numbers currently claim to be the grid factor:

- `Colony.gridFactor` — computed from stored post-tick `gridSupply`/`gridDemand`
- `ProductionAllocator`'s internal `energyFactor` — computed mid-tick

`MainColonyView` renders the first; the simulation obeys the second. They agree
today only because both are 1.0.

**Do:**
1. Change `ProductionAllocator.run` to return `(supply: Double, demand: Double,
   factor: Double)` — return the factor it actually used.
2. Add `var gridFactor: Double = 1` as a **stored** property on `Colony`; set it
   in `applyTick` from the returned value.
3. **Delete** the computed `gridFactor`. Keep `gridUtilisationPercent`.

**Files:** `Models/ProductionAllocator.swift`, `Models/Colony.swift`

**Acceptance:** builds clean; `MainColonyView`'s power pill still shows a
sensible percentage. Nothing visually changes yet — this is a correctness fix.

```
git commit -m "Single source of truth for the grid factor

ProductionAllocator now returns the factor it used; Colony stores it.
Removes the separately-computed Colony.gridFactor that the UI rendered
while the simulation obeyed a different number. HELIOS.md §18 S7."
```

---

## Step 3 — Temporary debug sink

**Scaffolding. Phase 2 deletes this.** See "Why a debug sink comes first" above.

**Do:** add `Models/DebugSink.swift`:

- A `static let enabled = true` flag, and a doc comment stating in the first line
  that this is temporary Phase-1 scaffolding to be removed when Quota lands.
- Per tick, drain each resource by a per-good rate, but **never below a floor of
  30% of capacity for `oxygen`, `ration-bars` and `water`** — without that floor
  the colonists die (measured: population reaches zero at high drain rates).
- Rates: use the export-capacity table in `HELIOS.md` Appendix C as the per-good
  per-minute rate, scaled by `economyRate`. That is "load 1.0" and it is the
  measured sweet spot.
- Call it from `Colony.applyTick` **after** production, guarded by the flag.

**Files:** new `Models/DebugSink.swift`, `Models/Colony.swift`

**Acceptance:** run for two minutes. Stores must fall away from their caps and
settle low (tradeables 0–10%; oxygen/rations/water held near 30%). Population must
stay at 450. Chains must show real throughput numbers instead of everything
reading "Output full".

```
git commit -m "Add temporary debug sink so the economy is observable

Phase 1 scaffolding, removed when Quota lands in Phase 2. Without a sink
the economy saturates by tick 60 and output % has no visible effect at
all. Rates from the measured export capacity in HELIOS.md Appendix C;
basic-need goods floored at 30% of storage so colonists survive."
```

---

## Step 4 — `outputPercent` in the model and the allocator (+ S6, + S15)

**The core change.** Three issues resolve together because they are the same
few lines.

### 4a. The field

Add to `ChainDetail`:

```swift
/// Player-set output rate, 0...1. Five stops: 0, 0.25, 0.5, 0.75, 1.
var outputPercent: Double = 1
```

Five coarse stops, not a continuous slider — this is a phone, and OGame's
steps-of-10 is already too fine for touch. Seed every sample chain at `1`.

### 4b. It scales desire, and therefore energy draw

In `ProductionAllocator.allocate`, the desired rate becomes:

```swift
desired[i] = min(outputCap[i], energyFactor) * chains[i].outputPercent
```

In `run`, the grid demand calculation becomes:

```swift
demand += chains[i].energyRequired * min(outputCap[i], 1) * chains[i].outputPercent
```

**This second line is also the fix for S6.** Demand previously used
`energyRequired * outputCap[i]` computed *before* input allocation, so a chain
that would actually run at 20% still booked 100% of its power draw. Now demand
reflects what the chain will actually draw — and turning a chain down frees power
for everything else, which is the whole point of the feature.

Apply `outputPercent` to energy producers too. A plant at 50% produces 50% of its
MW. It's meaningless today but correct, and fusion-style plants that burn fuel
will need it.

### 4c. Status is measured against what the player asked for (S15)

This is the part that matters most and is easiest to get wrong.

A chain running at exactly the rate the player requested is **running**, not
limited. Today `resolveStatus` compares achieved throughput against `1.0` with a
tolerance of `0.001`, so a chain at 99.5% reports "Limited by Raw Ice" in amber.
Measured: with a sink active, **eight of ten chains sit at 99–100% throughput and
all of them report `limited`, 100% of ticks.** The colony screen would be almost
entirely amber while running perfectly.

**Do:**

1. `if outputPercent <= 0 { return .paused }` — check this **first**. A paused
   chain is off by choice, not blocked, and must draw no inputs and no energy.
2. Compare achieved against **requested**, not against 1:
   `let attainment = achieved / outputPercent`
3. Widen the tolerance to `0.02`. `attainment >= 1 - 0.02` → `.running`.
4. Otherwise report the single tightest constraint as it does now.

**Files:** `Models/ChainDetail.swift`, `Models/ProductionAllocator.swift`

**Acceptance** (with the debug sink from Step 3 running):

- With everything at 100%: **eight of ten chains read "Running smoothly"**. Only
  Alloy Tool Fab and Cell Factory read "Limited by Refined Alloy" — that is the
  real structural bottleneck (Smelter supplies 7/min, they demand 5+3=8), and it
  is the one thing that *should* be amber.
- Set Alloy Tool Fab to 0 in code temporarily: its status reads **"Paused"**, its
  throughput 0%, and Refined Alloy stock climbs.
- Set it to 0.5: it runs at 50%, and the Alloy Smelter's throughput *drops*
  (less demand for its output) rather than rising.

```
git commit -m "Add per-chain outputPercent; fix grid demand and status tolerance

outputPercent (0...1, five stops) scales both production and energy draw,
so turning a chain down frees power for the rest of the colony.

Also fixes two issues that live in the same lines:
- S6: grid demand used output-capped desire computed before input
  allocation, so input-starved chains booked full power draw.
- S15: status compared achieved throughput against 1.0 with a 0.001
  tolerance, so chains at 99.5% reported 'Limited' in amber. Status is
  now measured against what the player requested, tolerance 0.02, and
  outputPercent == 0 reports .paused.

HELIOS.md §18 S6, S15."
```

---

## Step 5 — Mutating it from the UI

`game.activeColony` returns a **copy**. Views cannot write through it, and
`HELIOS.md` §14 requires mutating array elements by index and never
wholesale-replacing them.

**Do:** add to `GameState`:

```swift
func setOutputPercent(chainID: ChainDetail.ID, to value: Double) {
    let i = activeIndex
    guard let j = colonies[i].productionChains.firstIndex(where: { $0.id == chainID })
    else { return }
    colonies[i].productionChains[j].outputPercent = min(1, max(0, value))
}
```

Then add the control to `ProductionDetailView`, below the flow diagram and above
`WorkforceSection`:

- Five segments: **0% · 25% · 50% · 75% · 100%**
- Use `CategoryChip`-style glass segments or a custom segmented row — **design
  tokens only, no raw literals** (`HELIOS.md` §16)
- The active segment uses `GameTheme.accent`
- Label it "Output"
- Below it, one caption line: `"Running at X% · requested Y%"` when they differ

**Do not** put this control in the list row. It belongs on the detail screen —
the list stays scannable.

**Files:** `Models/GameState.swift`, `Screens/ProductionDetailView.swift`

**Acceptance:** tap through all five stops on a chain. Throughput and the output
summary respond within a tick. Set 0% → status reads "Paused". Navigate away and
back → the setting persists (in memory; real persistence is Phase 1.5).

```
git commit -m "Output % control on ProductionDetailView

GameState.setOutputPercent mutates by index per the architecture rule;
views cannot write through the activeColony copy. Five coarse stops
rather than a continuous slider — this is a phone."
```

---

## Step 6 — Surfacing it in the list

`ProductionChainRow` currently shows throughput % and a status dot.

**Do:**
- When `outputPercent < 1`, show a small badge reading e.g. `50%` next to the
  chain name, tinted `GameTheme.textSecondary` — **not** amber. A throttled chain
  is a deliberate choice, not a warning. Amber is reserved strictly for alerts and
  blocked states (`HELIOS.md` §16).
- When `outputPercent == 0`, the row dims to `0.55` opacity, matching the
  locked-tier and locked-research treatment.
- Leave the existing throughput % and status dot alone.

**Files:** `Components/ProductionChainRow.swift`

**Acceptance:** a throttled chain is identifiable at a glance from the colony
screen without being mistaken for a problem. A paused chain is visibly inactive.

```
git commit -m "Show throttled and paused state in ProductionChainRow

Throttle badge uses secondary tint, not amber — a deliberate choice is
not an alert. Paused chains dim, matching locked tiers and research."
```

---

## Definition of done

- [ ] Six commits, each building clean, each pushed
- [ ] With the debug sink on and all chains at 100%, exactly **two** chains read
      amber, both "Limited by Refined Alloy"
- [ ] Setting a chain to 0% reads "Paused" and it consumes nothing
- [ ] Throttling the Alloy Tool Fab visibly changes the Refined Alloy stock level
- [ ] `git log --oneline -6` reads as six distinct, accurate messages

## Then update the docs

Before closing the session, in `HELIOS.md`:

- §19 Phase 1: tick off output %, the S6/S7/S12/S15 fixes
- §18: mark S6, S7, S12, S15 resolved
- §21: record any decision made here that isn't already written down
- Note the debug sink as a known temporary, to be removed in Phase 2

Then re-sync the Claude project copy, and commit the doc update as its own
seventh commit.

---

## Open question to settle during the work

**Should `outputPercent` survive a chain being blocked?** Currently a chain at
50% that loses its input still remembers 50%. That's almost certainly right — the
player's intent shouldn't be erased by a transient shortage — but it means a chain
can sit at 0% for reasons the player forgot they caused. Consider whether the
"Paused" state needs to be more visually insistent than a dimmed row. Decide it
when you can see it, and record the answer in `HELIOS.md` §21.
