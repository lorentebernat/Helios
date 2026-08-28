"""Two hypotheses from run 1:

H1  A quota that names only 2 goods unsticks only those 2 chains. The rest of
    the colony still saturates. Breadth matters more than size.

H2  Because quota settles from stores on hand, quota size is capped by STORAGE
    CAPACITY, not production rate. A 600-minute interval at Patron demands more
    power-cells than the colony can physically hold, so it is unmeetable no
    matter how productive it is.
"""
import random, statistics
from sim import CAP, CHAINS, Stock, run_production, pop_tick

EXPORTABLE = ["alloy-tools", "power-cells", "ration-bars", "oxygen",
              "refined-alloy", "water", "grain", "raw-ice", "raw-ore"]
RATE = {"power-cells": 5.31, "raw-ore": 5.09, "alloy-tools": 2.80, "oxygen": 2.31,
        "raw-ice": 2.07, "grain": 2.06, "water": 0.56, "ration-bars": 0.23,
        "refined-alloy": 0.04}


def fresh():
    stock = Stock({"raw-ice": 120, "raw-ore": 90, "power-cells": 60, "water": 40,
                   "grain": 30, "oxygen": 112, "ration-bars": 180,
                   "refined-alloy": 0, "alloy-tools": 60})
    pop = [{"tier": "survivors", "count": 248.0, "cap": 300.0, "basic": 1.0, "happy": 1.0},
           {"tier": "settlers", "count": 0.0, "cap": 150.0, "basic": 1.0, "happy": 1.0}]
    return stock, pop, [1.0]*len(CHAINS), ["running"]*len(CHAINS)


def run(load=0.75, interval=240, n_goods=2, ticks=12000, seed=3,
        continuous=False, cap_to_storage=False):
    """continuous: shipment accrues each tick (a standing route) instead of
       settling in one lump at the deadline."""
    rng = random.Random(seed)
    stock, pop, thr, status = fresh()
    pool = [g for g in EXPORTABLE if RATE[g] > 0.05]
    fills, idle_hist, util = [], [], []

    def make(interval):
        goods = rng.sample(pool, min(n_goods, len(pool)))
        q = {}
        for g in goods:
            want = RATE[g] * interval * (load / len(goods)) * len(goods) / len(goods)
            want = RATE[g] * interval * load / len(goods) * len(goods)
            want = RATE[g] * interval * load          # per-good, at its own rate
            if cap_to_storage:
                want = min(want, CAP[g] * 0.8)
            q[g] = want
        return q

    quota = make(interval)
    delivered = {g: 0.0 for g in quota}
    due = interval

    for t in range(1, ticks + 1):
        pop_tick(pop, stock, 1.0)
        run_production(CHAINS, stock, 1.0, thr, status)

        if continuous:
            for g, amount in quota.items():
                per_tick = amount / interval
                take = min(per_tick, stock.amt(g))
                stock.drain(g, take)
                delivered[g] += take

        if t >= due:
            if not continuous:
                for g, amount in quota.items():
                    take = min(amount, stock.amt(g))
                    stock.drain(g, take)
                    delivered[g] = take
            num = sum(delivered[g] / RATE[g] for g in quota)
            den = sum(quota[g] / RATE[g] for g in quota)
            fills.append(num / den if den > 0 else 1.0)
            quota = make(interval)
            delivered = {g: 0.0 for g in quota}
            due = t + interval

        if t % 100 == 0 and t > 2000:
            idle_hist.append(sum(1 for s in status if s != "running"))
            util.append(statistics.mean(stock.amt(k)/CAP[k] for k in CAP))

    return (statistics.mean(fills[-15:]) if len(fills) >= 15 else statistics.mean(fills),
            statistics.mean(idle_hist), statistics.mean(util))


print("═" * 78)
print("H1 — DOES BREADTH BEAT SIZE?   (load 0.75, 240-min interval, lump settlement)")
print("═" * 78)
print(f"{'goods named':>12} {'fill':>8} {'chains idle':>13} {'avg store fill':>16}")
print("-" * 78)
for n in [1, 2, 3, 5, 7, 9]:
    f, idle, u = run(load=0.75, n_goods=n)
    print(f"{n:>12} {f:>8.2f} {idle:>9.1f}/10 {u:>15.0%}")

print("\n" + "═" * 78)
print("H2 — IS QUOTA CAPPED BY STORAGE?   (5 goods, load 0.75)")
print("═" * 78)
print(f"{'interval':>10} {'demand vs storage':>20} {'fill':>8} {'fill if capped':>16}")
print("-" * 78)
for iv in [60, 120, 240, 480, 960]:
    # worst-case good: how much is demanded vs what the colony can hold
    worst = max(EXPORTABLE, key=lambda g: RATE[g] * iv * 0.75 / CAP[g])
    demand = RATE[worst] * iv * 0.75
    ratio = demand / CAP[worst]
    f_plain, _, _ = run(load=0.75, interval=iv, n_goods=5)
    f_capped, _, _ = run(load=0.75, interval=iv, n_goods=5, cap_to_storage=True)
    print(f"{iv:>10} {worst+f' {ratio:.1f}×cap':>20} {f_plain:>8.2f} {f_capped:>16.2f}")

print("\n" + "═" * 78)
print("LUMP SETTLEMENT vs CONTINUOUS SHIPMENT   (5 goods, 240-min interval)")
print("═" * 78)
print(f"{'load':>6} {'lump fill':>11} {'cont. fill':>12} {'lump idle':>11} {'cont. idle':>12}")
print("-" * 78)
for load in [0.25, 0.50, 0.75, 1.00, 1.25]:
    fl, il, _ = run(load=load, n_goods=5, continuous=False)
    fc, ic, _ = run(load=load, n_goods=5, continuous=True)
    print(f"{load:>6.2f} {fl:>11.2f} {fc:>12.2f} {il:>7.1f}/10 {ic:>8.1f}/10")

print("\n" + "═" * 78)
print("BEST CONFIG — continuous, all 9 goods, capped to storage")
print("═" * 78)
print(f"{'load':>6} {'fill':>8} {'chains idle':>13} {'avg store fill':>16}")
print("-" * 78)
for load in [0.25, 0.50, 0.75, 0.90, 1.00, 1.10]:
    f, idle, u = run(load=load, n_goods=9, continuous=True, cap_to_storage=True)
    print(f"{load:>6.2f} {f:>8.2f} {idle:>9.1f}/10 {u:>15.0%}")
