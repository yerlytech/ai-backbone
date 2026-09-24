---
status: done
date: 2026-09-13
---

# 002 — backbone polish

## What

The last items from spec 001's review, applied to this repo only: the sidebar
of a project shows seven things a person owns, the backbone tests itself, a
Claude session starts by reading the journal, the four human commands speak
the maintainer's language, and `just publish` can create the GitHub repo.

## Why

After 1.1.0 a project still showed `CLAUDE.md`, `GEMINI.md` and an empty
`.env.example`; every change to `core.just` was tested by hand; the agent had
to remember to run `just session-start`; the person read English lines from
commands they type in Turkish; publishing needed a copied command. The
maintainer approved all of it on 2026-09-13 in one sentence.

## Not doing

- Migrating other projects (`games`). That is their session. The bridge files
  stay until then and are only hidden from the sidebar.
- Deleting `CLAUDE.md`: Claude Code does not read `AGENTS.md` on its own
  (checked in its docs), so the one-line pointer stays.
- Enforcing "spec before code" with a hook. Small fixes need no spec.

## Questions

None open.

## Acceptance

- [x] A fresh project's sidebar shows `README.md AGENTS.md Justfile LICENSE docs/ src/ brain/`
      and nothing else. `.env.example` appears with the first secret, not before.
- [x] `CLAUDE.md` is the single line `@AGENTS.md`.
- [x] `just self-test` passes: a new project from the current backbone and a
      project made from the `v0.3.1` tag migrated to the current layout.
- [x] `.claude/settings.json` carries a `SessionStart` hook that runs
      `just session-start`, in the backbone and in every new project.
- [x] With `chat_lang: tr`, `just`, `just save`, `just undo` and `just publish`
      speak Turkish; with anything else, English.
- [x] `just publish` with no remote and a logged-in `gh` offers to create a
      private repo, then pushes with tags.
- [x] `just undo` also drops staged changes and says so when there is nothing to undo.
- [x] `tools` is `claude` here; the Copilot and Junie copies are gone from this repo.
- [x] The backbone is pushed to its GitHub remote with tags.

## Tasks

- [x] Sidebar: hide the pointers and bridges; drop `.env.example` from the seed and the root.
- [x] `self-test.sh` and the `just self-test` recipe; seed Justfile split from the backbone's.
- [x] SessionStart hook in the seed `.claude/settings.json`.
- [x] `_msg` helper; `help`, `save`, `undo`, `publish` use it.
- [x] `publish` creates the repo; `undo` resets the index too.
- [x] CHANGELOG 1.2.0, tag, journal, push.
