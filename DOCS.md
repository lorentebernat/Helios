# Where the documentation lives

Read this if you're not sure which file to trust.

## One rule

**`HELIOS.md` is the single source of truth.** Design decisions, current state,
systems, the plan, and the decision log live there and only there. If any other
document disagrees with it, `HELIOS.md` is right and the other one is stale.

Everything else is one of three things: a **superseded stub**, a **reference
input**, or a **dated snapshot**. None of them are authoritative.

## The files

| File | Kind | Trust it for |
|---|---|---|
| **`HELIOS.md`** | ✅ **Authoritative** | Everything. Premise, systems, architecture, phases, decisions, known issues, gotchas. |
| `HELIOS_DESIGN.md` | ⚠️ Superseded stub | Nothing. Folded into `HELIOS.md` on 28 Aug 2026. Full text in git history. |
| `HELIOS_ROADMAP.md` | ⚠️ Superseded stub | Nothing. Folded into `HELIOS.md` §19. Full text in git history. |
| `HELIOS_WORLD.md` | ⚠️ Superseded stub | Nothing. Folded into `HELIOS.md` Part I. Full text in git history. |
| `OGAME_COMPARISON.md` | 📚 Reference input (Aug 2026) | OGame's formulas, the combat spec, the option/trade-off analysis behind decisions already taken. **Its recommendations are not the plan** — see `HELIOS.md` Appendix A for what was actually taken. |
| `../sources/` (31 files) | 📚 Reference input | Anno 1800 mechanics. A *different game*. Nothing in it describes Helios. |

Also, in the **Claude project**:

| Doc | Kind | Trust it for |
|---|---|---|
| `claude/HELIOS.md` | 🔁 Mirror | Same content, synced by hand. The repo copy is canonical. |
| `claude/AUDIT-2026-08-28.md` | 📌 Dated snapshot | Evidence and reproduction for the issues in `HELIOS.md` §18. Valid only for commit `e5ae9ca`. **Live status is §18, not this file.** |
| Anno 1800 library (31 docs) | 📚 Reference input | Same as `../sources/`. |

## Rules for keeping it that way

1. **New decisions go in `HELIOS.md` §21**, with rationale and rejected
   alternatives. That log is append-only.
2. **Research goes in a reference file**, and its *conclusion* gets recorded in
   `HELIOS.md`. Never leave a decision only in a research doc.
3. **Snapshots get a date in the filename** and are never edited afterwards.
4. **Re-sync the Claude project copy** whenever `HELIOS.md` changes materially.
5. **Don't create a fourth `HELIOS_*.md`.** If it feels like it needs its own
   file, it's probably a section.

## Known housekeeping

- ⚠️ The Anno library sits at `Helios/sources/`, **outside** the git repo
  (`Helios/Helios/`). It is untracked and unbacked-up. Move it in, or decide
  deliberately that it stays out.
- ⚠️ The Claude project holds **two documents at the path `HELIOS_DESIGN.md`**
  (12 Aug and 20 Aug). Path lookups resolve to the newest, so the 12 Aug copy can
  neither be read nor replaced through the API. It still holds full stale design
  text, it will surface in project search, and it is the one Helios document with
  no copy in git. **Delete it manually in claude.ai** — reading it first if you
  want to confirm nothing in it is unique.
- ⚠️ **The repo has no remote.** It exists on one disk.
