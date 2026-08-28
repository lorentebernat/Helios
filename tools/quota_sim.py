"""Quota + Standing on top of the Helios allocator port.

Step 1: measure true export capacity (production net of colonist consumption).
Step 2: run quota scenarios at fractions of that capacity and see what happens.
"""
import random, statistics
from sim import (CAP, CHAINS, Stock, run_production, pop_tick, BASIC, LUX)

EXPORTABLE = ["alloy-tools", "power-cells", "ration-bars", "oxygen",
              "refined-alloy", "water", "grain", "raw-ice", "raw-ore"]


def fresh():
    stock = Stock({"raw-ice": 120, "raw-ore": 90, "power-cells": 60, "water": 40,
                   "grain": 30, "oxygen": 112, "ration-bars": 180,
                   "refined-alloy": 0, "alloy-tools": 60})
    pop = [{"tier": "survivors", "count": 248.0, "cap": 300.0, "basic": 1.0, "happy": 1.0},
           {"tier": "settlers", "count": 0.0, "cap": 150.0, "basic": 1.0, "happy": 1.0}]
    return stock, pop, [1.0]*len(CHAINS), ["running"]*len(CHAINS)


# ── Step 1: export capacity ────────────────────────────────────────────────
# Perfect sink: every tick, drain everything above a small working buffer.
# Whatever the colony still manages to accumulate IS its export capacity.
def measure_capacity(ticks=3000, buffer_frac=0.25):
    stock, pop, thr, status = fresh()
    exported = {k: 0.0 for k in CAP}
    for t in range(ticks):
        pop_tick(pop, stock, 1.0)
        run_production(CHAINS, stock, 1.0, thr, status)
        if t > 500:                       # let it settle first
            for k in EXPORTABLE:
                keep = CAP[k] * buffer_frac
                if stock.amt(k) > keep:
                    take = stock.amt(k) - keep
                    stock.drain(k, take)
                    exported[k] += take
    n = ticks - 500
    return {k: v / n for k, v in exported.items() if v > 0}, pop, thr, status


cap_rate, pop_end, thr_end, status_end = measure_capacity()
print("═" * 74)
print("EXPORT CAPACITY — units per game-minute, net of colonist consumption")
print("═" * 74)
for k, v in sorted(cap_rate.items(), key=lambda x: -x[1]):
    print(f"  {k:<16} {v:7.2f}/min      ({v*60:8.0f} per game-hour)")
print(f"\n  population at steady state: " +
      " ".join(f"{p['tier']}={p['count']:.0f}" for p in pop_end))
stalled = sum(1 for s in status_end if s != "running")
print(f"  chains not running with a perfect sink: {stalled}/{len(CHAINS)}")
for i, c in enumerate(CHAINS):
    if status_end[i] != "running":
        print(f"      ! {c[0]:<18} {status_end[i]:<26} {thr_end[i]*100:5.1f}%")


# ── Step 2: quota + standing ───────────────────────────────────────────────
BANDS = ["Receivership", "Scrutinised", "Indifferent", "Favourable", "Patron"]
# interval multiplier per band — worse standing = more frequent, smaller
INTERVAL_MULT = {"Receivership": 0.4, "Scrutinised": 0.7,
                 "Indifferent": 1.0, "Favourable": 1.5, "Patron": 2.5}
UP = [0.55, 0.75, 0.90, 0.97]      # thresholds to rise into band i+1
DOWN = [0.45, 0.65, 0.82, 0.92]    # thresholds to fall out of band i+1 (hysteresis)


def band_of(idx):
    return BANDS[idx]


def run_quota(load, base_interval=240, ticks=20000, seed=7, goods_per_quota=2,
              rotate=True):
    """load = quota size as a fraction of export capacity over the interval."""
    rng = random.Random(seed)
    stock, pop, thr, status = fresh()
    band = 2                                    # Indifferent
    reliability = 1.0                           # EMA
    hist, stall_hist, band_hist = [], [], []
    pool = [k for k in cap_rate if cap_rate[k] > 0.05]

    def make_quota(interval):
        goods = rng.sample(pool, min(goods_per_quota, len(pool))) if rotate \
                else pool[:goods_per_quota]
        # split the load across the named goods
        per = load / len(goods)
        return {g: cap_rate[g] * interval * per for g in goods}

    interval = base_interval * INTERVAL_MULT[band_of(band)]
    quota = make_quota(interval)
    due = interval

    for t in range(1, ticks + 1):
        pop_tick(pop, stock, 1.0)
        run_production(CHAINS, stock, 1.0, thr, status)

        if t >= due:
            # settle from stores on hand
            delivered = demanded = 0.0
            for g, amount in quota.items():
                take = min(amount, stock.amt(g))
                stock.drain(g, take)
                delivered += take / max(cap_rate[g], 1e-9)   # normalise by value
                demanded += amount / max(cap_rate[g], 1e-9)
            ratio = delivered / demanded if demanded > 0 else 1.0
            reliability = 0.7 * reliability + 0.3 * ratio     # EMA
            # band movement with hysteresis
            if band < 4 and reliability >= UP[band]:
                band += 1
            elif band > 0 and reliability < DOWN[band - 1]:
                band -= 1
            hist.append(ratio)
            band_hist.append(band)
            interval = base_interval * INTERVAL_MULT[band_of(band)]
            quota = make_quota(interval)
            due = t + interval

        if t % 50 == 0:
            stall_hist.append(sum(1 for s in status if s != "running"))

    return {
        "load": load,
        "cycles": len(hist),
        "mean_fill": statistics.mean(hist) if hist else 1.0,
        "final_fill": statistics.mean(hist[-10:]) if len(hist) >= 10 else float("nan"),
        "band": band_of(band),
        "reliability": reliability,
        "stalled_late": statistics.mean(stall_hist[-40:]) if stall_hist else 0,
        "pop": sum(p["count"] for p in pop),
    }


print("\n" + "═" * 74)
print("QUOTA SCENARIOS — 20,000 game-minutes (~14 game-days), 240-min base interval")
print("═" * 74)
print(f"{'load':>6} {'cycles':>7} {'mean fill':>10} {'late fill':>10} "
      f"{'end band':>13} {'chains idle':>12} {'pop':>6}")
print("-" * 74)
for load in [0.0, 0.25, 0.50, 0.75, 0.90, 1.00, 1.25]:
    if load == 0.0:
        stock, pop, thr, status = fresh()
        for t in range(20000):
            pop_tick(pop, stock, 1.0)
            run_production(CHAINS, stock, 1.0, thr, status)
        idle = sum(1 for s in status if s != "running")
        print(f"{'none':>6} {'—':>7} {'—':>10} {'—':>10} {'—':>13} "
              f"{idle:>8}/{len(CHAINS)} {sum(p['count'] for p in pop):>6.0f}")
        continue
    r = run_quota(load)
    print(f"{r['load']:>6.2f} {r['cycles']:>7} {r['mean_fill']:>10.2f} "
          f"{r['final_fill']:>10.2f} {r['band']:>13} "
          f"{r['stalled_late']:>8.1f}/{len(CHAINS)} {r['pop']:>6.0f}")
