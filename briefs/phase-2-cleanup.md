# Cleanup Brief — Phase 2 follow-up (for Claude Code)

**Written 14 Oct 2026**, after a four-way review of Phase 2 (ten commits,
`briefs/phase-2-the-empire.md`).

**Read first:** `HELIOS.md` §4 (the Empire), §16 (visual language), §18 (known
issues), §19 (phases), §21 (decision log), Appendix C (balance baseline).

You are working directly in the repo at
`~/Documents/Bernat/Development/Helios/Helios`. Edit files, run the test suite,
and commit. You do not need to hand code back for pasting.

---

## Ground rules

**Verify before you change.** This brief was produced by review and hand-tracing,
not by running the code. Items are marked **[VERIFIED]** (confirmed by reading the
relevant lines) or **[SUSPECTED]** (traced by hand, could be wrong). For every
**[SUSPECTED]** item, reproduce it first — usually by running the test or adding a
temporary assertion. **If it does not reproduce, say so and move on. Do not
"fix" something that isn't broken.**

**Run the suite after every step.** `⌘U` equivalent:

```bash
xcodebuild test -scheme Helios -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40
```

Get a baseline before you touch anything — some tests may already be red.

**Commit after every step.** Never two steps in one commit, never `--amend`.

```bash
git add -A && git status --short
git commit -m "<message from the step>"
git push
```

End every commit message with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01P3r1XSiziY4NdGx7jtzxUN
```

**Out of scope — do not touch:**
- ❌ The load-1.0 balance question (§4.2 "meetable with no effort at all"). That is
  an open *design* decision, not a bug. Leave it exactly as documented.
- ❌ Any new feature, any Phase 3 work.
- ❌ The multi-colony ledger issue and the Phase-4 catch-up issue in Step 2 —
  those are **annotate only**, see below.

---

## Step 0 — Baseline

Run the suite. Record which tests pass and which fail, in the commit message of
Step 1 or in your first report back. Several claims below depend on knowing this.

In particular, check **`CommissionTests.onlyOneCommissionIsOfferedAtATime`**.
**[SUSPECTED]** it is currently red. Hand-trace: `withCommissionOffered()` lands at
tick 240 with commission id 1 and `deadlineFraction = 0.5`, so the contract closes
at tick 360; the test then runs a further `intervalTicks` to 480, where settlement
offers commission id 2; the assertion `commission?.id == first.id || commission == nil`
then evaluates `2 == 1 || false`.

If it is red, fix it in Step 3 (it is listed there). If it is green, work out why
the trace is wrong and note it — that matters more than the test.

No commit for this step.

---

## Step 1 — Two real bugs

### 1a. The stipend readout lies after every band change **[VERIFIED]**

`GameState.stipendForAMetQuota`:

```swift
var stipendForAMetQuota: Int {
    Int((Self.stipendPerGameMinute
         * quotaCadenceMinutes          // ← the CURRENT band's cadence
         * standing.band.stipendMultiplier).rounded())
}
```

The live manifest deliberately keeps the window it was issued with
(`theBandDrivesTheAnnouncedCadence` pins exactly this: `currentQuota?.intervalMinutes == 240`
while `quotaCadenceMinutes == 360`). So for one full cycle after every band move,
the panel shows a number the Empire will not pay.

Worked example — fresh game, tick 240, first settlement promotes Indifferent →
Favourable:
- Panel shows `1.25 × 360 × 1.2 = 540`
- Actual next payment `1.25 × 240 × 1.2 = 360`
- **50% overstatement.** Symmetric on the way down: after Indifferent →
  Scrutinised the panel says 147 and the payment is 210.

Shown in `MainColonyView` and `QuotaDetailView` via `QuotaPanel.stipendIfMet`.

**Fix:** use the live manifest's own interval, falling back to the cadence only
when there is no current quota:

```swift
* (currentQuota?.intervalMinutes ?? quotaCadenceMinutes)
```

**The existing test cannot catch this** — `StipendTests.fixedCadence()` sets
`quotaCadenceOverrideMinutes = baseIntervalMinutes`, which makes the two values
equal by construction. Step 3 fixes the test. Do the code fix here and watch the
test stay green (it will — that's the point).

### 1b. The planet re-rolls on every launch **[VERIFIED]**

`MainColonyView` passes `seed: game.activeColony.id.hashValue` to `PlanetBackdrop`.
`Colony.ID` is a `String` slug, and **Swift seeds `String.hashValue` randomly per
process**. Stable within a run, different on every launch.

This reopens S12, which `HELIOS.md` §18 claims closed with: *"`PlanetBackdrop` now
takes a `seed: Int` … so a given world looks identical every time it's opened."*
It also sits badly next to §14's determinism constraint and the whole point of
`SeededGenerator`.

**Fix:** derive a stable integer from the slug. Put it next to `SeededGenerator`
in `Shared/`, e.g. an FNV-1a over the UTF-8 bytes:

```swift
extension String {
    /// Launch-stable hash. `hashValue` is per-process seeded in Swift and must
    /// not be used for anything that should look the same across launches.
    var stableSeed: Int { /* FNV-1a over utf8 */ }
}
```

Use it at both call sites (`MainColonyView`, and check `DestinationCard` for the
same mistake).

**Add a test:** same slug hashed twice gives the same value, and two different
slugs give different values. A cross-launch test isn't possible in-process — the
real guard is that `hashValue` no longer appears. Consider a grep-style note in
§23 instead.

```
git commit -m "Fix stipend readout and launch-unstable planet seed

stipendForAMetQuota used the current band's cadence while the live
manifest keeps the window it was issued with, so the panel overstated
the payment by 50% for a full cycle after every band promotion.

MainColonyView seeded PlanetBackdrop from String.hashValue, which Swift
seeds randomly per process — the planet changed on every launch, which
is exactly what S12 claimed to have fixed. Replaced with a stable hash.
"
```

---

## Step 2 — Two latent issues: annotate, do not fix

Both are real but not reachable today. Fixing them now means designing against a
phase that doesn't exist. **Add a clearly-worded `// TODO Phase N:` at the exact
site and a line in `HELIOS.md` §18 (a new S16 and S17). Change no behaviour.**

**2a. `settleQuotaIfDue` drops the announced manifest if a tick is skipped**
**[VERIFIED]**. It promotes `nextQuota` via `announced.issuedAtTick == tickCount`.
`isDue` is `tick >= dueAtTick`, so if `tickCount` ever advances by more than one
between checks the equality fails and a fresh quota is generated — breaking the
"you always get a full interval to retool" promise. Unreachable today; **Phase 4's
offline catch-up is precisely what will trigger it.**

**2b. One ledger shared across colonies** **[VERIFIED]**. `GameState.tick()` passes
`&ledger` to every colony in the loop, while `generateQuota` sizes from
`colonies[activeIndex]` alone. With more than one colony the scheduled allocation
is consumed by whichever colony iterates first. There is already a TODO on
`generateQuota`; add the matching one on the tick loop and on
`offerCommissionIfNoneOutstanding`, which sizes from the active colony too and
would let a player change the next contract by switching colonies in the UI.

```
git commit -m "Annotate two latent Empire issues (S16, S17)

Neither is reachable today; both are recorded rather than fixed so the
phase that triggers them finds them already described.

S16: settlement promotes the announced manifest by tick equality, so a
skipped tick regenerates instead — Phase 4 catch-up will hit this.
S17: a single quota ledger is threaded through every colony while sizing
reads only the active one. Phase 7 multi-colony.
"
```

---

## Step 3 — Give the tests teeth

The suite is large and reads confidently, but several of its most important tests
cannot fail against the regression they name. **This is the highest-value step in
this brief.**

Note the pattern before you start: *the tests with the longest, most confident
comments are systematically the hollow ones.* The comment substituted for asking
whether the assertion could fail.

### 3a. The anti-spiral test is tautological **[VERIFIED]** — fix this one first

`StandingTests.failureNeverRaisesTheDemandRate` calls itself *"the single most
important test in this phase"*. It settles ten cycles at fill 0 — then compares
two direct calls to `QuotaGenerator.generate` with different `intervalMinutes`.
**The generator never receives the band.** Delete the ten settlements and the test
passes identically.

Since `lines[good] = capacity × interval × load` and `totalDemandPerGameMinute =
Σlines / interval`, the interval cancels algebraically. It is two invocations of
the same code with a different scalar.

The invariant **does hold** — that was verified separately. The problem is that
nothing protects it. If someone routes the band into `GameState.generateQuota` and
adds a penalty there, this test stays green.

**Write the end-to-end version:** drive the real state with `tick()` until the band
actually falls, read `state.currentQuota!.totalDemandPerGameMinute` before and
after, and assert they match. Keep the existing unit-level test too if you like,
but rename it to something honest (`sizingIsIntervalInvariant`) and move the
"most important test" comment to the new one.

While you're there: the `1e-9` tolerance survives only because the seed network's
capacities land on exact tenths and `(raw*10).rounded()/10` cleans the float noise.
Any rebalance that moves a capacity off a tenth puts this test red **for the wrong
reason**. Add a comment saying so, so the next person doesn't "fix" it by loosening
the tolerance.

### 3b. The stipend test checks its own arithmetic **[VERIFIED]**

`StipendTests.incomePerGameMinuteRisesWithTheBand` computes
`payment = stipendPerGameMinute * cadence * multiplier`, then asserts
`payment / cadence == stipendPerGameMinute * multiplier`. That is `x == x`. It
never calls `payStipend`, never ticks, never reads `settlement.stipend`.

Worse: **no test in the suite exercises `payStipend` at a cadence other than 240.**
`fixedCadence()` pins it; the seed game is 240; `shipyardBecomesSustainable` leaves
it free but only asserts a very loose lower bound. At 240 minutes, "per shipment"
and "flat per cycle" are indistinguishable — so the design's whole point is
untested.

**Write:** run a full cycle at Patron (cadence 600) with no override and assert
`settled.stipend == 1125`. Then do the same at Scrutinised (168) and assert 147.

Also fix `fixedCadence(band:)`: it takes a band and pins the cadence to 240
regardless, which is the exact decoupling that hides this bug. Either make it
honour the band's cadence or drop the parameter.

And its reliability seed (`riseThresholds[band.rawValue] - 0.01`) sits 0.01 below
a promotion — one perfect settlement moves the band. Fine for single-cycle tests,
wrong the moment anyone adds a second cycle. Move it further from the threshold.

### 3c. Assertions pointing the wrong way **[VERIFIED]**

`CommissionTests.theQuotaCollectsBeforeTheCommission` asserts
`fill <= plainFills[i] + 1e-9`. If the commission *stole* from the quota — the
actual defect — the fill would be **lower**, and lower passes. Change to equality:
the quota must fill *exactly* the same with or without a contract running.

`CommissionTests.failingCostsMoreThanDeliveringPays` compares
`CommissionGenerator.standingPenalty > .standingReward` — the generator's statics.
`resolveCommissionIfDue` uses the *contract's* fields. Swap the two at the
generator's call site and the test still passes. Assert on a generated contract.

`CommissionTests.contractsAreSizedWithinTheDrawableHeadroom` asserts
`0.35·H ≤ H`, true for any intensity ≤ 1. It does not catch the bug it names: if
`storageHeadroom` forgot the reserve floor and returned full capacity, the
assertion still passes. Assert against the floor directly.

### 3d. A helper that neuters its own test **[VERIFIED]**

`CommissionTests.commissionsNeverBreachTheReserveFloor` calls `stockUp()`, which
fills every store to capacity. The contract line is `0.245 × cap`; delivering all
of it leaves `0.755 × cap` against a floor of `0.30 × cap` — **45 percentage points
of slack.** The property cannot be violated in this fixture.

Rewrite it starting from stores **near the floor**, with a contract asking for more
than is drawable. That is the scenario that matters.

### 3e. The known tautology, still there **[VERIFIED]**

`HeliosTests.gridFactorMatchesAllocator` recomputes `min(1, supply/demand)` from
the same struct the implementation stored. It passed against the buggy version it
was written to guard, and it passes now.

Either give it teeth (construct a case where the allocator's factor is *not*
derivable from the stored supply/demand) or **delete it and keep only the second
assertion** (`gridFactor < 1`, "this really is a brownout"), with a comment saying
the single-source property is structural and not behaviourally testable. Deleting
a hollow test is an improvement; leaving it is a false sense of coverage.

### 3f. Cheap additions with real value

- **`outputPercent` in `saveRoundTrips`.** Set a chain to 0.37 before encoding and
  assert the restored value matches. (`ChainDetail`'s `CodingKeys` do include
  `outputPercent` — **[VERIFIED]** — so this should pass. Add it anyway: it is the
  player's only lever and nothing currently guards it.)
- **Clock-freedom.** `let before = state.lastTickAt; state.tick();
  #expect(state.lastTickAt == before)`. The paired determinism tests cannot catch a
  `Date()` inside `tick()` — they tick A and B interleaved, so both would read
  nearly the same clock and diverge only *intermittently*, which is the worst
  possible failure mode.
- **`meanStoreFill < 0.55` hides a saturated store.** Oxygen sits above 0.90 by
  design, and the mean over nine goods absorbs one good going from 0.4 to 1.0
  (~0.067 shift). Add a per-good assertion for everything except oxygen.
- **Self-conditioned assertions** (`if attainment >= 0.98 { #expect(...) }` in
  `noChainReportsLimitedWhileAtRate`, and the same shape in
  `theEmpireNeverDrawsBelowTheReserveFloor`). If a regression zeroes throughput the
  body never runs and the test passes green. Count executions and assert the count
  is greater than zero.
- **`cadenceLengthDoesNotChangeTheEconomy`** covers 96–600. `QuotaLedger`'s header
  claims the measurement spans 60, 240, 960 and 2,880. Extend the loop so the test
  says what the comment says.
- **`receivershipUnderAPunishingLoadStillLeavesAColony`** asserts
  `population > 0` while its comment says *"Measured: 101 colonists left"*. A
  collapse from 101 to 3 passes. Pin the measured figure with a tolerance.

```
git commit -m "Give the Phase 2 tests teeth

Several tests could not fail against the regression they named:

- failureNeverRaisesTheDemandRate compared two calls to QuotaGenerator
  with different scalars; the band never reaches the generator, and its
  ten settlements were decorative. Added the end-to-end version that
  drives a real band drop.
- incomePerGameMinuteRisesWithTheBand reimplemented payStipend and
  checked its own arithmetic. No test ran payStipend at a cadence other
  than 240, where per-shipment and flat-per-cycle are indistinguishable.
- theQuotaCollectsBeforeTheCommission asserted in the opposite direction
  to the defect; failingCostsMoreThanDeliveringPays compared the
  generator's statics rather than the contract's fields.
- commissionsNeverBreachTheReserveFloor used a fixture that left 45
  percentage points of slack above the floor.

Plus outputPercent round-trip, a clock-freedom assertion, per-good store
assertions, and execution counts on self-conditioned expectations.
"
```

---

## Step 4 — Amber means something again

§16: *"Amber (`GameTheme.warn`) reserved **strictly** for alerts and blocked
states."*

**`CommissionCard`** **[VERIFIED]** breaks it twice:

```swift
private var tint: Color {
    guard commission.accepted else { return GameTheme.accent }
    return wouldBeMet ? GameTheme.accent : GameTheme.warn
}
```

The moment a contract is accepted, `wouldBeMet` is false — nothing has been
delivered yet — and the whole card turns amber with *"Short. A contract is paid in
full or not at all."* A freshly accepted contract with its entire window ahead is
not an alert. Same again at the per-line shortfall tint, which paints amber on a
contract the player **hasn't even accepted**, based on current stock, when a
commission is a rush order you fill by *producing* during the window.

`QuotaLineRow` solves this correctly in the file next door, and its comment
explains exactly why: *"Colouring by raw progress would paint almost every line
amber for most of every cycle, which is how a warning colour stops meaning
anything."*

**Fix:** give `Commission` a schedule concept — mirror `Quota.scheduledFraction(atTick:)`
— and colour against *pace*, not raw progress. Amber only when the contract is
genuinely behind its own clock, or when its window is nearly gone.

**Also in this step, and check it carefully:** `QuotaPanel.isOffTrack` is
`fill < 0.95 && minutesRemaining <= 0.001`. **[SUSPECTED]** that amber never
appears at all, because `minutesRemaining <= 0.001` is true only on the exact due
tick, and settlement promotes the next cycle on that same tick. Verify, then make
it compare `fill` against `scheduledFraction` the way `QuotaLineRow` does — the
comment already describes that behaviour.

**Raw literals.** The new UI uses `.yellow` and `.green` (`MainColonyView`), and
`.white.opacity(0.08)` for progress-bar tracks in three separate files — a de-facto
token with no name. Fonts are `.system(size:)` throughout the new components while
`GameTheme.Font` has nine members, and several spacings are raw numbers that
exactly equal existing tokens (`20` ≡ `Spacing.xl`, `10` ≡ `Spacing.sm`, `6` ≡
`Spacing.xs`). Add the two or three missing tokens (a track fill, a progress-bar
height) and replace the literals. Keep this proportionate — fix the colours and
anything that duplicates an existing token; don't invent a token for every one-off
number.

**Previews.** `QuotaPanel`, `QuotaLineRow`, `CommissionCard` and
`DismissedCommissionRow` have none, and `GameState.seeded()` has `commission: nil`,
so **no commission UI path is previewable at all** — the "dormant cases rot"
condition from §23. Add previews with a sample commission.

```
git commit -m "Amber only for genuine alerts; tokens for the Phase 2 UI

CommissionCard turned an entire freshly-accepted contract amber because
nothing had been delivered yet, and painted per-line warnings on
contracts the player hadn't accepted. Commissions now colour against
pace, mirroring QuotaLineRow.

Adds the missing tokens the new components were working around, and
previews for the commission UI, which had none and is unreachable from
seeded state.
"
```

---

## Step 5 — Reconcile the docs

`HELIOS.md` has drifted again, this time **internally**: §4.2 contradicts
Appendix C, §21 and the code — and in one case contradicts itself two paragraphs
apart. Appendix C, §21 and the code agree with each other; **treat those as the
truth and rewrite §4.2 against them.**

All **[VERIFIED]**:

| Where | Says | Should say |
|---|---|---|
| §4.2 "Colonists eat first" | settlers at **0.86 happiness**, "the intended squeeze" | §4.2 itself retracts this two paragraphs earlier: the squeeze came from the Phase 1a debug sink and **does not exist at load 1.00**. Remove the stale claim. |
| §4.2 Sizing table | pop at load 3.0 = **229** | Appendix C / §21 / code: **206** |
| §4.2 "Colonists eat first" | 192 with floor, 90 without; 89 at load 4.0 | **206 / 108**, and **101 / 0** |
| §4.2 ledger section | fill **0.59, 0.59, 0.60, 0.60** | Measured now: **1.0000** in all five bands |
| §4.2 ledger section | snapshot demand is **19×** storage | 5.25 × 960 / 200 = **25×** |
| §4.2 Sizing table | stores settle at **29% mean** | **0.40** (§18 S1; the Appendix C list averages 0.3989) |
| §4.8 | "Verified across 60 → 2,880 minute intervals (Appendix C)" | Appendix C measures **96–600**. Either fix the citation or extend the measurement (Step 3f extends the test). |
| §23 | "`ChainDetail.ID` is currently registered in two places" | Fixed in Phase 1.5. **Dangerous** — this is the section someone reads while debugging a dead tap. |
| §18 S10 | "`status` is a `let`" | It is a `var` since Phase 1.5. The rest of S10 (research is inert) still stands. |
| §13, §14, §4.5 | Buildings "Phase 4", hazards/combat "Phase 7", score "Phase 5", `economyRate` to 1/60 in "Phase 3" | Post-renumbering: **5, 8, 6, 4** |
| §14 Navigation | payloads: `ChainDetail.ID`, `ShipRouteTarget`, `ProductionListNav` | `QuotaDetailNav` is missing |
| §4.7 | "no currency has two sinks" — while giving Credits "Writs, ships" | Credits already has two. Reword the rule or the table. |
| §21 / `Standing.swift` / `GameState.swift` | "income per game-minute exactly `stipendMultiplier`" with the ladder 0 / 0.875 / 1.25 / 1.5 / 1.875 | Those are credits per game-minute (multiplier × 1.25). `stipendMultiplier` is 0 / 0.7 / 1.0 / 1.2 / 1.5. Reword — Phase 6 turns Standing into the visible score and someone will tune the wrong constant. |
| Appendix C header | dated **28 Aug 2026** | Its first subsection refutes the 28 August figures. Re-date to Phase 2. |

```
git commit -m "Reconcile HELIOS.md with Appendix C and the code

§4.2 had drifted onto six stale figures and contradicted its own
retraction of the colonist squeeze two paragraphs earlier. Appendix C,
§21 and the code agreed with each other; §4.2 is now rewritten against
them.

Also: §23 warned about a navigation bug fixed in Phase 1.5 — the section
people read while debugging a dead tap; S10 claimed a let that is a var;
§13/§14/§4.5 kept five pre-renumbering phase numbers; §14 was missing
QuotaDetailNav; and the 'income per game-minute equals stipendMultiplier'
wording names a constant whose value it isn't.
"
```

---

## Step 6 — The three housekeeping items, finally

All three have survived two phases.

**6a. S9** — move `ResearchCategory.icon` out of `Models/ResearchProject.swift`
into `DesignSystem/ModelStyles.swift` and drop `import SwiftUI` from the model.
Five minutes; it is the last model-purity violation and the whole multiplayer plan
rests on that constraint.

**6b. The `tools/` harness.** `DOCS.md` says it mirrors the Swift by hand and
drifts. It has: still `TOL = 0.001`, no `outputPercent`, pre-Phase-1a status rule.
**And there is a bigger question** — Appendix C attributes Phase 2 measurements
(settled fill per cadence, the Standing EMA and hysteresis table, a commission
table over 4,800 ticks) to this harness, but a port of only `ProductionAllocator`
and `Population` cannot produce them: they need `Quota`, `QuotaLedger`, `Standing`,
`Commission` and `CapacityProbe`.

Work out which is true — did the harness grow, or do those numbers come from the
Swift tests? — and make the attribution honest. If the harness is dead, say so in
its README and in Appendix C rather than leaving a stale provenance claim on the
document's entire evidence base.

**6c. Appendix B** doesn't list `briefs/` or `tools/`, though §19 cites three
briefs and Appendix C depends on `tools/`. `DOCS.md` lists both. Since `DOCS.md`
declares `HELIOS.md` the single source of truth, the authoritative map currently
says two directories don't exist. Add them.

```
git commit -m "Housekeeping: S9, tools/ provenance, Appendix B

Moves ResearchCategory.icon to ModelStyles and drops SwiftUI from the
model layer — the last purity violation, and the constraint the
multiplayer plan depends on.

Resolves what tools/ actually is: Appendix C credited it with Phase 2
measurements a port of ProductionAllocator and Population cannot produce.

Appendix B now lists briefs/ and tools/, which existed only in DOCS.md.
"
```

---

## Definition of done

- [ ] Suite green, and green on repeated runs (no parallel flakiness)
- [ ] Every **[SUSPECTED]** item either reproduced-and-fixed or reported as
      not-reproducing, with what you found instead
- [ ] Six commits (or five, if Step 0 found nothing to carry), each pushed
- [ ] `grep -rn "hashValue" Helios/` returns nothing in view code
- [ ] `grep -rn "import SwiftUI" Helios/Models/` returns nothing
- [ ] No figure in §4.2 disagrees with Appendix C

## Report back

Say plainly which **[SUSPECTED]** items did not reproduce — that is more useful
than the fixes. And if you find a test you cannot make meaningful, say so and
propose deleting it; a hollow test is worse than no test, because it buys
confidence it hasn't earned.
