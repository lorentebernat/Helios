# tools/ — balance simulation harness

A line-for-line Python port of `ProductionAllocator` and `Population`, used to
measure the seed economy without building anything in Swift. Produced the figures
in `HELIOS.md` Appendix C.

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
