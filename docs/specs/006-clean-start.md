---
status: done
date: 2026-09-14
---

# 006 — clean start

## What

One commit of history for the backbone and for each of the six projects, under
the maintainer's current identity. The migration code for 0.x and 1.x projects
is removed with it, since no such project exists any more. The old history of
every repo is kept as a git bundle in that repo's private `brain/`.

## Why

Every earlier commit carried a deleted account's name. The information in the
history is already in `CHANGELOG.md` and the journals; the only thing the
commits added was the wrong name and forty lines of noise. The maintainer
decided on 2026-09-14, before the backbone goes anywhere near public.

## Not doing

- Rewriting the author on each commit instead of squashing. More work for a
  history nobody needs to read.
- Touching `.archive/legacy/` in the games: the bundles of their pre-backbone
  repos stay exactly as they are.

## Questions

None open. Approved on 2026-09-14 ("başla").

## Acceptance

- [x] `git log` in the backbone shows one commit, author Yerly Tech, tag v3.0.0;
      GitHub shows the same and no older tags.
- [x] Each of the six projects shows one commit, author Yerly Tech, working tree clean.
- [x] Each repo has `brain/history-before-3.0.0.bundle` and `git bundle verify` accepts it.
- [x] No file outside `CHANGELOG.md` and `docs/specs/` mentions `ai-first`,
      `AI_FIRST_REPO` or `template-manifest`.
- [x] `just self-test` passes; `just projects` shows six projects on 3.0.0.

## Tasks

- [x] Remove the migration paths; self-test; docs; CHANGELOG 3.0.0.
- [x] Bundle, squash, tag, force-push the backbone.
- [x] Update, bundle and squash the six projects.
