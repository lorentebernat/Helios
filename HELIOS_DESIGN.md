# HELIOS_DESIGN.md — superseded

> **This document is no longer maintained.**
> Its content was reconciled into **[`HELIOS.md`](HELIOS.md)** on 28 August 2026.

Go to `HELIOS.md`. Nothing here overrides it.

| What used to be here | Where it is now |
|---|---|
| §1 Working method, prior art | `HELIOS.md` §22 |
| §2 Guiding principles | `HELIOS.md` §2 |
| §3 Visual language, design system | `HELIOS.md` §16 |
| §4 Project structure, sample-data convention | `HELIOS.md` §15 |
| §5 Architecture (scope split, state, navigation, game loop) | `HELIOS.md` §14 |
| §6 Portability / multiplayer hedges | `HELIOS.md` §14 |
| §7 Game systems (production, population, fleet, research) | `HELIOS.md` §8–§12 |
| §8 Decision log | `HELIOS.md` §21 |
| §9 Open work, known simplifications | `HELIOS.md` §18, §19, §20 |
| §10 Gotchas | `HELIOS.md` §23 |

**Why it was retired:** it had drifted from the code. It claimed Phase 0 complete
with Phase 1 next when most of Phase 1 had landed; described `ChainStatus` as a
three-case enum; described a per-chain tick algorithm that no longer exists; said
"nine-chain seed network" when there are ten; and omitted six fields from the
`ChainDetail` table. The drift is recorded in `HELIOS.md` §21.

The full original text is preserved in git history (commit `e5ae9ca` and earlier).
