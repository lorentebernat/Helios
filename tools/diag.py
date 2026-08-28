import statistics
from sim import CAP, CHAINS, Stock, run_production, pop_tick
RATE = {"power-cells":5.31,"raw-ore":5.09,"alloy-tools":2.80,"oxygen":2.31,
        "raw-ice":2.07,"grain":2.06,"water":0.56,"ration-bars":0.23,"refined-alloy":0.04}
GOODS=list(RATE); FOOD={"oxygen","ration-bars","water"}

def run(load, interval=240, ticks=15000):
    stock=Stock({"raw-ice":120,"raw-ore":90,"power-cells":60,"water":40,"grain":30,
                 "oxygen":112,"ration-bars":180,"refined-alloy":0,"alloy-tools":60})
    pop=[{"tier":"survivors","count":248.0,"cap":300.0,"basic":1.0,"happy":1.0},
         {"tier":"settlers","count":0.0,"cap":150.0,"basic":1.0,"happy":1.0}]
    thr=[1.0]*len(CHAINS); status=["running"]*len(CHAINS)
    acc={i:[] for i in range(len(CHAINS))}; reasons={}
    quota={g:RATE[g]*interval*load for g in GOODS}
    for t in range(1,ticks+1):
        pop_tick(pop,stock,1.0); run_production(CHAINS,stock,1.0,thr,status)
        for g in GOODS:
            floor=CAP[g]*0.30 if g in FOOD else 0.0
            stock.drain(g,min(quota[g]/interval,max(0.0,stock.amt(g)-floor)))
        if t>3000:
            for i in range(len(CHAINS)):
                acc[i].append(thr[i])
                if status[i]!="running": reasons.setdefault(i,{}); \
                    reasons[i][status[i]]=reasons[i].get(status[i],0)+1
    return stock,pop,acc,reasons

for load in (1.0,):
    stock,pop,acc,reasons=run(load)
    print("═"*78); print(f"STEADY STATE AT LOAD {load}"); print("═"*78)
    print(f"{'chain':<20}{'mean throughput':>17}   dominant limit")
    print("-"*78)
    for i,c in enumerate(CHAINS):
        m=statistics.mean(acc[i])
        r=reasons.get(i,{})
        top=max(r,key=r.get) if r else "running"
        pct=(r[top]/sum(r.values())*100) if r else 100
        print(f"{c[0]:<20}{m*100:>15.0f}%   {top}  ({pct:.0f}% of ticks)")
    print("\nstock at end (% of cap):")
    print("  "+"  ".join(f"{k}={stock.amt(k)/CAP[k]:.0%}" for k in sorted(CAP)))
    print("population:", " ".join(f"{p['tier']}={p['count']:.0f} happy={p['happy']:.2f}" for p in pop))
