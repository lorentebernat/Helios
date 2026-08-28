"""Faithful Python port of Helios ProductionAllocator + Population, to test the
seed economy. Mirrors the Swift line-for-line."""

CAP = {
    "raw-ice": 250, "raw-ore": 300, "power-cells": 200, "water": 200,
    "grain": 200, "oxygen": 200, "ration-bars": 400,
    "refined-alloy": 150, "alloy-tools": 150,
}

# name, inputs{id:rate}, output(id,rate)|None, energyProduced, energyRequired
CHAINS = [
    ("Ice Harvester",    {},                              ("raw-ice", 20),       0,   10),
    ("Ore Extractor",    {},                              ("raw-ore", 15),       0,   12),
    ("Power Plant",      {},                              None,                240,    0),
    ("Water Reclaimer",  {"raw-ice": 8},                  ("water", 12),         0,   15),
    ("Oxygen Recycler",  {"raw-ice": 10},                 ("oxygen", 12),        0,   15),
    ("Hydroponics Bay",  {"water": 6},                    ("grain", 10),         0,   18),
    ("Ration Bar Synth", {"grain": 8, "water": 4},        ("ration-bars", 6),    0,   20),
    ("Alloy Smelter",    {"raw-ore": 10},                 ("refined-alloy", 7),  0,   30),
    ("Alloy Tool Fab",   {"refined-alloy": 5},            ("alloy-tools", 4),    0,   25),
    ("Cell Factory",     {"refined-alloy": 3},            ("power-cells", 6),    0,   25),
]

BASIC = {
    "survivors": {"oxygen": 2.0, "ration-bars": 1.2},
    "settlers":  {"oxygen": 2.5, "ration-bars": 1.5, "water": 1.0},
}
LUX = {"survivors": {}, "settlers": {"alloy-tools": 0.5}}
GROWTH, DECLINE, ATTRITION, PROMO = 3.0, 6.0, 0.5, 2.0
TOL = 0.001


class Stock(dict):
    def amt(self, k): return self.get(k, 0.0)
    def dep(self, k, q): self[k] = min(CAP.get(k, 0), self.amt(k) + q)
    def drain(self, k, q): self[k] = max(0.0, self.amt(k) - q)


def allocate(idxs, chains, stock, rate, efactor, ocap, thr, status):
    if not idxs: return
    desired = {i: min(ocap[i], efactor) for i in idxs}
    demand = {}
    for i in idxs:
        for rid, r in chains[i][1].items():
            demand[rid] = demand.get(rid, 0) + desired[i] * r * rate
    ratio = {rid: (1.0 if w <= 0 else min(1.0, stock.amt(rid) / w)) for rid, w in demand.items()}
    for i in idxs:
        inf, binding = 1.0, None
        for rid in chains[i][1]:
            r = ratio.get(rid, 1.0)
            if r < inf: inf, binding = r, rid
        ach = desired[i] * inf
        for rid, rr in chains[i][1].items():
            stock.drain(rid, ach * rr * rate)
        if chains[i][2]:
            stock.dep(chains[i][2][0], ach * chains[i][2][1] * rate)
        thr[i] = ach
        tightest = min(inf, efactor, ocap[i])
        if tightest >= 1 - TOL: status[i] = "running"
        elif inf <= efactor and inf <= ocap[i] and binding: status[i] = f"limited:{binding}"
        elif efactor <= ocap[i]: status[i] = "limited:power"
        else: status[i] = "stalled"


def run_production(chains, stock, rate, thr, status):
    ocap = [1.0] * len(chains)
    for i, c in enumerate(chains):
        if not c[2]: continue
        want = c[2][1] * rate
        if want <= 0: continue
        head = max(0.0, CAP.get(c[2][0], 0) - stock.amt(c[2][0]))
        ocap[i] = min(1.0, head / want)
    prod = [i for i, c in enumerate(chains) if c[3] > 0]
    cons = [i for i, c in enumerate(chains) if c[3] <= 0]
    allocate(prod, chains, stock, rate, 1.0, ocap, thr, status)
    supply = sum(chains[i][3] * thr[i] for i in prod)
    demand = sum(chains[i][4] * ocap[i] for i in cons)
    ef = 1.0 if demand <= 0 else min(1.0, supply / demand)
    allocate(cons, chains, stock, rate, ef, ocap, thr, status)
    return supply, demand, ef


def pop_tick(pop, stock, rate):
    demand = {}
    for t in pop:
        if t["count"] <= 0: continue
        for rid, per in list(BASIC[t["tier"]].items()) + list(LUX[t["tier"]].items()):
            demand[rid] = demand.get(rid, 0) + (t["count"] / 100) * rate * per
    ratio = {rid: (1.0 if w <= 0 else min(1.0, stock.amt(rid) / w)) for rid, w in demand.items()}
    for t in pop:
        if t["count"] <= 0:
            t["basic"], t["happy"] = 1.0, 1.0
            continue
        sat = 1.0
        for rid, per in BASIC[t["tier"]].items():
            want = (t["count"] / 100) * rate * per
            if want <= 0: continue
            sh = ratio.get(rid, 1.0)
            sat = min(sat, sh)
            stock.drain(rid, want * sh)
        t["basic"] = sat
        lux = LUX[t["tier"]]
        if not lux:
            t["happy"] = 1.0
        else:
            s = 0.0
            for rid, per in lux.items():
                want = (t["count"] / 100) * rate * per
                sh = ratio.get(rid, 1.0) if want > 0 else 1.0
                s += sh
                stock.drain(rid, want * sh)
            t["happy"] = s / len(lux)
    for t in pop:
        if t["count"] <= 0: continue
        if t["basic"] >= 0.999:
            if t["count"] < t["cap"]:
                t["count"] = min(t["cap"], t["count"] + GROWTH * rate)
            if t["happy"] < 1:
                t["count"] = max(0, t["count"] - ATTRITION * (1 - t["happy"]) * rate)
        else:
            t["count"] = max(0, t["count"] - DECLINE * (1 - t["basic"]) * rate)
    for i in range(len(pop) - 1, -1, -1):
        f = pop[i]
        if f["count"] <= 0 or f["basic"] < 0.999 or f["happy"] < 1 or i + 1 >= len(pop): continue
        free = pop[i + 1]["cap"] - pop[i + 1]["count"]
        if free <= 0: continue
        mv = min(PROMO * rate, f["count"], free)
        f["count"] -= mv
        pop[i + 1]["count"] += mv


stock = Stock({"raw-ice": 120, "raw-ore": 90, "power-cells": 60, "water": 40,
               "grain": 30, "oxygen": 112, "ration-bars": 180,
               "refined-alloy": 0, "alloy-tools": 60})
pop = [{"tier": "survivors", "count": 248.0, "cap": 300.0, "basic": 1.0, "happy": 1.0},
       {"tier": "settlers", "count": 0.0, "cap": 150.0, "basic": 1.0, "happy": 1.0}]
thr = [1.0] * len(CHAINS)
status = ["running"] * len(CHAINS)

_marks_unused = {1, 5, 30, 60, 120, 300, 600, 1200}
if __name__ == "__main__":
  for t in range(1, 1201):
    pop_tick(pop, stock, 1.0)
    supply, demand, ef = run_production(CHAINS, stock, 1.0, thr, status)
    if t in marks:
        print(f"\n─── tick {t} (grid {supply:.0f}/{demand:.0f} MW, factor {ef:.2f}) ───")
        print("  pop:", " ".join(f"{p['tier']}={p['count']:.0f}/{p['cap']:.0f}"
                                 f"(b{p['basic']:.2f},h{p['happy']:.2f})" for p in pop))
        print("  stock:", " ".join(f"{k}={v:.0f}" for k, v in sorted(stock.items())))
        for i, c in enumerate(CHAINS):
            if status[i] != "running":
                print(f"    ! {c[0]:<18} {status[i]:<24} thr {thr[i]*100:.0f}%")
