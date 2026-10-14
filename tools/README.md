# tools/ — balance simulation harness

> ⚠️ **Frozen: valid as of Phase 1a (28 Aug 2026).** Unchanged since commit
> `c58bfd9`. It still has `TOL = 0.001`, no `outputPercent`, the pre-Phase-1a
> status rule, and no `CapacityProbe`, `QuotaLedger`, `Standing` or
> `Commission`. **It did not produce the Phase 2 figures in `HELIOS.md`
> Appendix C** — those were measured by the Swift simulation itself
> (`GameState.tick()`, `CapacityProbe`), and the load-bearing ones are pinned
> in `HeliosTests/`. Only the struck-through 28 Aug figures came from here, and
> Appendix C explains why they were wrong. Do not re-tune anything with this
> harness; measure in Swift instead.

A line-for-line Python port of `ProductionAllocator` and `Population` as they
stood in Phase 1a, used to measure the seed economy before the Swift test target
existed.

| File | What it does |
|---|---|
| `sim.py` | The port itself: `Stock`, `run_production` (two-phase proportional allocation), `pop_tick`. Import it; run it directly for the no-sink saturation demo. |
| `quota_sim.py` | Measures export capacity, then sweeps quota load with snapshot settlement + standing bands. |
| `quota_sim2.py` | Tests breadth-vs-size, the storage-cap trap, and lump vs ledger delivery. |
| `quota_sim3.py` | Ceiling sweep: finds the usable load band and what breaks first. |
| `diag.py` | Per-chain throughput and binding constraint at a given load. |

## Keeping it honest

This mirrors the Swift by hand, so **it drifts the moment `ProductionAllocator`
or `Population` changes.** Before trusting a number from it, diff it against the
Swift. The port is small enough (~120 lines) that re-checking is quick.

Every figure in Appendix C is a measurement of the *current* seed data — chain
rates, resource capacities, population tuning. Change any of those and re-run:

```
python3 quota_sim.py     # export capacity
python3 quota_sim3.py    # load ceiling
python3 diag.py          # per-chain steady state
```

Once the Swift test target exists (Phase 1.5), the saturation scenario and the
load-1.0 steady state should become real XCTest cases and this harness becomes
exploratory-only.
