---
status: done
date: 2026-09-14
---

# 007 — the backbone works on its own

## What

A scheduled agent, running somewhere other than the maintainer's machine,
works through the backbone's backlog: one item per run, tested, pushed. The
backbone ships the brief (`.ai-backbone/routine.md`) and stays neutral about
who runs it. For that to work, notes must reach GitHub by themselves
(`backbone-note` saves and sends) and the local backbone must pull what came
in (`session-start`).

## Why

The maintainer wants the backbone to get stronger without their attention.
Other people who take the backbone may not connect GitHub to Claude, or may
schedule with Cursor; the backbone must not assume one vendor. Every cloud
option needs the same two things anyway: the backbone on GitHub, and that
vendor allowed to read and push it. None needs a server.

## Not doing

- Touching the projects from the cloud. They are on this machine only.
- More than one item per run. A small correct change a day beats a large one.
- Creating the routine inside the backbone. The routine is the maintainer's
  account's, made once, from the brief.

## Questions

None open. The maintainer asked for scheduler neutrality on 2026-09-14.

## Acceptance

- [x] In a project, `just backbone-note "x"` leaves the backbone with a clean
      tree and a commit "docs: backlog note from <project>"; pushed when a
      remote answers, otherwise it says so.
- [x] In the backbone, `just session-start` says pulled / up to date / not
      reachable / not pulled because of unsaved work.
- [x] `.ai-backbone/routine.md` exists, is listed under `[backbone]`, and can be
      pasted as a prompt with nothing else.
- [x] The getting-started page lists the three schedulers and what each needs.
- [x] `just self-test` covers the note's own save.

## Tasks

- [x] `backbone-note` saves and sends; `session-start` pulls.
- [x] `routine.md`; manifest; backbone-dev skill; docs; CHANGELOG 3.1.0.
- [x] Self-test check; save, tag, publish.
