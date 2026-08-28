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
| `sources/` (31 files) | 📚 Reference input | Anno 1800 mechanics. A *different game*. Nothing in it describes Helios. |
| `briefs/*.md` | 🔨 Working doc | How to build one specific phase. Dated, disposable, never authoritative. |
| `tools/*.py` | 🔬 Harness | Balance simulation. Produced Appendix C. Mirrors the Swift by hand — verify before trusting. |

Also, in the **Claude project**:

| Doc | Kind | Trust it for |
|---|---|---|
| `claude/HELIOS.md` | 🔁 Mirror | Same content, synced by hand. The repo copy is canonical. |
| `claude/AUDIT-2026-08-28.md` | 📌 Dated snapshot | Evidence and reproduction for the issues in `HELIOS.md` §18. Valid only for commit `e5ae9ca`. **Live status is §18, not this file.** |
| Anno 1800 library (31 docs) | 📚 Reference input | Same as `sources/` in the repo. |

## Rules for keeping it that way

1. **New decisions go in `HELIOS.md` §21**, with rationale and rejected
   alternatives. That log is append-only.
2. **Research goes in a reference file**, and its *conclusion* gets recorded in
   `HELIOS.md`. Never leave a decision only in a research doc.
3. **Snapshots get a date in the filename** and are never edited afterwards.
4. **Re-sync the Claude project copy** whenever `HELIOS.md` changes materially.
5. **Don't create a fourth `HELIOS_*.md`.** If it feels like it needs its own
   file, it's probably a section.
6. **Implementation briefs live in `briefs/`**, named for the phase. They are
   working documents with a shelf life: when the work lands, fold any decision
   they made into `HELIOS.md` §21 and let the brief go stale in git history.
   A brief is never authoritative — `HELIOS.md` is.
7. **`tools/` mirrors the Swift by hand and drifts.** Re-check it against
   `ProductionAllocator` and `Population` before trusting a number from it.

## Known housekeeping

- ✅ **Resolved.** The Anno library used to sit outside the git repo and was
  untracked. It now lives at `sources/` inside the work tree and is version
  controlled. It is static — a diff touching it means something went wrong.
- ✅ **Resolved.** The Claude project had held two documents at the path
  `HELIOS_DESIGN.md` (12 Aug and 20 Aug). The older was invisible to `project_read`
  but live in search, so it was still able to answer questions with stale content.
  Three details unique to it were rescued into `HELIOS.md` first; both copies are
  now deleted and replaced by a single stub. **If you ever suspect a duplicate,
  search the project — don't trust the file listing.**
- ✅ **Resolved.** The repo now has a private GitHub remote (`origin`,
  personal account via the `github-personal` SSH alias). Push with a bare
  `git push` — upstream tracking is set.
