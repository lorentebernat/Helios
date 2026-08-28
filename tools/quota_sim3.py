"""Where is the ceiling? Continuous (ledger) delivery, all 9 goods, uncapped.
Push load until the colony can no longer meet it, and watch what breaks first."""
import random, statistics
from sim import CAP, CHAINS, Stock, run_production, pop_tick

RATE = {"power-cells": 5.31, "raw-ore": 5.09, "alloy-tools": 2.80, "oxygen": 2.31,
        "raw-ice": 2.07, "grain": 2.06, "water": 0.56, "ration-bars": 0.23,
        "refined-alloy": 0.04}
GOODS = list(RATE)


def fresh():
    stock = Stock({"raw-ice": 120, "raw-ore": 90, "power-cells": 60, "water": 40,
                   "grain": 30, "oxygen": 112, "ration-bars": 180,
                   "refined-alloy": 0, "alloy-tools": 60})
    pop = [{"tier": "survivors", "count": 248.0, "cap": 300.0, "basic": 1.0, "happy": 1.0},
           {"tier": "settlers", "count": 0.0, "cap": 150.0, "basic": 1.0, "happy": 1.0}]
    return stock, pop, [1.0]*len(CHAINS), ["running"]*len(CHAINS)


def run(load, interval=240, ticks=15000, protect_food=True):
    stock, pop, thr, status = fresh()
    fills, idle_hist, util, shortfall = [], [], [], {}
    quota = {g: RATE[g]*interval*load for g in GOODS}
    delivered = {g: 0.0 for g in GOODS}
    due = interval
    FOOD = {"oxygen", "ration-bars", "water"}
    RESERVE = 0.30                      # keep 30% of storage as a colonist buffer

    for t in range(1, ticks+1):
        pop_tick(pop, stock, 1.0)
        run_production(CHAINS, stock, 1.0, thr, status)

        for g in GOODS:                 # ledger delivery, a slice each tick
            per_tick = quota[g]/interval
            floor = CAP[g]*RESERVE if (protect_food and g in FOOD) else 0.0
            take = min(per_tick, max(0.0, stock.amt(g)-floor))
            stock.drain(g, take)
            delivered[g] += take

        if t >= due:
            num = sum(delivered[g]/RATE[g] for g in GOODS)
            den = sum(quota[g]/RATE[g] for g in GOODS)
            fills.append(num/den)
            for g in GOODS:
                if delivered[g] < quota[g]*0.98:
                    shortfall[g] = shortfall.get(g, 0)+1
            delivered = {g: 0.0 for g in GOODS}
            due = t+interval

        if t % 100 == 0 and t > 3000:
            idle_hist.append(sum(1 for s in status if s != "running"))
            util.append(statistics.mean(stock.amt(k)/CAP[k] for k in CAP))

    return (statistics.mean(fills[-15:]), statistics.mean(idle_hist),
            statistics.mean(util), sum(p["count"] for p in pop),
            sorted(shortfall, key=shortfall.get, reverse=True)[:3])


print("═"*82)
print("CEILING SWEEP — ledger delivery, all 9 goods, 240-min interval, food reserved")
print("═"*82)
print(f"{'load':>6} {'fill':>7} {'chains idle':>13} {'stores':>8} {'pop':>6}  {'first to fall short'}")
print("-"*82)
for load in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0]:
    f, idle, u, pop, short = run(load)
    print(f"{load:>6.1f} {f:>7.2f} {idle:>9.1f}/10 {u:>7.0%} {pop:>6.0f}  {', '.join(short) or '—'}")

print("\n" + "═"*82)
print("WHAT IF FOOD IS NOT RESERVED?  (does quota starve the colony?)")
print("═"*82)
print(f"{'load':>6} {'fill':>7} {'pop reserved':>14} {'pop unreserved':>16}")
print("-"*82)
for load in [1.0, 2.0, 3.0, 4.0]:
    f1, _, _, p1, _ = run(load, protect_food=True)
    f2, _, _, p2, _ = run(load, protect_food=False)
    print(f"{load:>6.1f} {f2:>7.2f} {p1:>14.0f} {p2:>16.0f}")

print("\n" + "═"*82)
print("INTERVAL NO LONGER MATTERS UNDER LEDGER DELIVERY (load 2.0)")
print("═"*82)
print(f"{'interval':>10} {'fill':>7} {'chains idle':>13}")
print("-"*82)
for iv in [60, 240, 960, 2880]:
    f, idle, _, _, _ = run(2.0, interval=iv)
    print(f"{iv:>10} {f:>7.2f} {idle:>9.1f}/10")
